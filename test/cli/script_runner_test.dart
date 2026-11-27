import 'package:rps/rps.dart';
import 'package:rps/src/cli/script_runner.dart';
import 'package:test/test.dart';

import '../mocks/fake_file_system.dart';
import '../mocks/fake_platform.dart';
import '../mocks/script_source.mock.dart';
import '../scripts_parser/scripts_parser_test.dart';

class _Run {
  final FakeExecutor executor;
  final String output;

  _Run(this.executor, this.output);
}

Future<_Run> _run(
  String scripts,
  List<String> arguments, {
  bool dryRun = false,
  int exitCode = 0,
  FakeFileSystem? fs,
  Map<String, String> processEnvironment = const {},
  bool assumeYes = false,
  bool interactive = false,
  Confirm? confirm,
}) async {
  final executor = FakeExecutor(exitCode: exitCode, executions: []);
  final output = StringBuffer();
  final events = ScriptsParser(
    source: MockedScriptSource(scripts),
    platform: const FakePlatform(),
  ).getCommandsToExecute(arguments);
  await ScriptRunner(
    executor: executor,
    console: Console(sink: output, ansi: false),
    dryRun: dryRun,
    fs: fs ?? FakeFileSystem(),
    processEnvironment: processEnvironment,
    assumeYes: assumeYes,
    interactive: interactive,
    confirm: confirm ?? (_) => fail('Unexpected question.'),
  ).run(events);
  return _Run(executor, output.toString());
}

void main() {
  group('ScriptRunner', () {
    test('runs commands in order and stops at the first failure', () async {
      const scripts = r'''
scripts:
  build:
    $before: echo before
    $script: echo build
    $after: echo after
''';
      final passed = await _run(scripts, ['build']);
      expect(
        passed.executor.executions,
        equals(['echo before', 'echo build', 'echo after']),
      );

      final executor = FakeExecutor(exitCode: 3, executions: []);
      final events = ScriptsParser(
        source: MockedScriptSource(scripts),
        platform: const FakePlatform(),
      ).getCommandsToExecute(['build']);
      await expectLater(
        ScriptRunner(
          executor: executor,
          console: Console(sink: StringBuffer()),
        ).run(events),
        throwsA(isA<ScriptFailedException>()
            .having((e) => e.exitCode, 'exitCode', 3)),
      );
      expect(executor.executions, equals(['echo before']));
    });

    group(r'$confirm', () {
      const scripts = r'''
scripts:
  reset:
    $confirm: Drop the database?
    $script: echo reset
  all:
    $steps:
      - echo first
      - rps reset
      - rps reset
''';

      test('asks once, before anything runs', () async {
        final questions = <String>[];
        late final FakeExecutor executor;
        final events = ScriptsParser(
          source: MockedScriptSource(scripts),
          platform: const FakePlatform(),
        ).getCommandsToExecute(['all']);
        executor = FakeExecutor(exitCode: 0, executions: []);
        await ScriptRunner(
          executor: executor,
          console: Console(sink: StringBuffer()),
          interactive: true,
          confirm: (message) {
            expect(executor.executions, isEmpty);
            questions.add(message);
            return true;
          },
        ).run(events);

        expect(questions, equals(['Drop the database?']));
        expect(
          executor.executions,
          equals(['echo first', 'echo reset', 'echo reset']),
        );
      });

      test('runs nothing when the user declines', () async {
        await expectLater(
          _run(scripts, ['all'], interactive: true, confirm: (_) => false),
          throwsA(isA<RpsException>()
              .having((e) => e.message, 'message', 'Cancelled.')
              .having((e) => e.exitCode, 'exitCode', 1)),
        );
      });

      test('fails without a terminal', () async {
        await expectLater(
          _run(scripts, ['reset']),
          throwsA(isA<RpsUsageException>()
              .having(
                (e) => e.message,
                'message',
                'The script "reset" asks for confirmation: '
                    'Drop the database?',
              )
              .having((e) => e.hint, 'hint', contains('--yes'))),
        );
      });

      test('does not ask when confirmed up front', () async {
        final run = await _run(scripts, ['reset'], assumeYes: true);

        expect(run.executor.executions, equals(['echo reset']));
      });

      test('shows the question in a dry run', () async {
        final run = await _run(scripts, ['reset'], dryRun: true);

        expect(run.executor.executions, isEmpty);
        expect(run.output, startsWith('? Drop the database?\n\n> reset\n'));
      });
    });

    group(r'$steps', () {
      const scripts = r'''
scripts:
  lint: echo lint
  check:
    $steps:
      - echo format
      - rps lint
      - echo test
''';

      test('runs every step and numbers them', () async {
        final run = await _run(scripts, ['check']);

        expect(
          run.executor.executions,
          equals(['echo format', 'echo lint', 'echo test']),
        );
        expect(run.output, contains('> check [1/3]\n\$ echo format\n'));
        expect(run.output, contains('> check [2/3]\n\$ rps lint\n'));
        expect(run.output, contains('> lint\n\$ echo lint\n'));
        expect(run.output, contains('> check [3/3]\n\$ echo test\n'));
      });

      test('prints every step in a dry run', () async {
        final run = await _run(scripts, ['check'], dryRun: true);

        expect(run.executor.executions, isEmpty);
        expect(run.output, contains('> check [3/3]\n\$ echo test\n'));
      });
    });

    group(r'$env', () {
      const scripts = r'''
scripts:
  $envFile: .env
  $env: {FROM_KEY: key, BOTH: key}
  build:
    $envFile: .env.build
    $script: echo build
  plain:
    nested: echo plain
''';

      test('passes variables from the keys and the files', () async {
        final run = await _run(
          scripts,
          ['build'],
          fs: FakeFileSystem(files: {
            '/project/.env': 'FROM_FILE=file\nBOTH=file\nOVERRIDDEN=first\n',
            '/project/.env.build': 'OVERRIDDEN=second\n',
          }),
        );

        expect(run.executor.environments.single, {
          'FROM_FILE': 'file',
          'OVERRIDDEN': 'second',
          'FROM_KEY': 'key',
          'BOTH': 'key',
        });
      });

      test('a file does not replace a variable of the process', () async {
        final run = await _run(
          scripts,
          ['plain', 'nested'],
          fs: FakeFileSystem(files: {
            '/project/.env': 'FROM_FILE=file\nHOME=/tmp\n',
          }),
          processEnvironment: {'HOME': '/home/me', 'FROM_KEY': 'process'},
        );

        expect(run.executor.environments.single, {
          'FROM_FILE': 'file',
          'FROM_KEY': 'key',
          'BOTH': 'key',
        });
      });

      test('fails when a file does not exist', () async {
        await expectLater(
          _run(scripts, ['plain', 'nested']),
          throwsA(isA<RpsConfigException>().having(
            (e) => e.message,
            'message',
            equals('The env file ".env" does not exist.'),
          )),
        );
      });

      test('passes no environment without the keys', () async {
        final run = await _run('scripts:\n  a: echo a\n', ['a']);

        expect(run.executor.environments, equals([null]));
      });

      test('does not read files or print values in a dry run', () async {
        final run = await _run(scripts, ['build'], dryRun: true);

        expect(run.output, isNot(contains('key')));
      });
    });

    group(r'$cwd', () {
      const scripts = r'''
scripts:
  app:
    $cwd: packages/app
    build: echo build
  plain: echo plain
''';

      test('runs the command in the directory', () async {
        final run = await _run(
          scripts,
          ['app', 'build'],
          fs: FakeFileSystem(directories: {'/project/packages/app': []}),
        );

        expect(
          run.executor.workingDirectories
              .map((directory) => directory?.replaceAll(r'\', '/')),
          equals(['/project/packages/app']),
        );
        expect(run.output, contains('> app build (packages/app)\n'));
      });

      test('leaves the directory unset without the key', () async {
        final run = await _run(scripts, ['plain']);

        expect(run.executor.workingDirectories, equals([null]));
        expect(run.output, contains('> plain\n'));
      });

      test('fails when the directory does not exist', () async {
        await expectLater(
          _run(scripts, ['app', 'build']),
          throwsA(isA<RpsConfigException>().having(
            (e) => e.message,
            'message',
            equals(
              'The working directory "packages/app" of the script '
              '"app build" does not exist.',
            ),
          )),
        );
      });

      test('does not check the directory in a dry run', () async {
        final run = await _run(scripts, ['app', 'build'], dryRun: true);

        expect(run.executor.executions, isEmpty);
        expect(run.output, contains('> app build (packages/app)\n'));
      });
    });
  });
}
