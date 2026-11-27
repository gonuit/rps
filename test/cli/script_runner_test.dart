import 'package:rps/rps.dart';
import 'package:test/test.dart';

import '../mocks/fake_executor.dart';
import '../mocks/fake_file_system.dart';
import '../mocks/fake_platform.dart';
import '../mocks/fake_prompt.dart';
import '../mocks/script_source.mock.dart';

class _ScriptedExecutor extends Executor {
  _ScriptedExecutor(this.exitCodes) : super(shell: const PosixShell());

  final Map<String, int> exitCodes;
  final started = <String>[];
  final stopped = <String>[];

  @override
  Future<int> execute(
    String command, {
    Shell? shell,
    Map<String, String>? environment,
    String? workingDirectory,
    CommandOutput? output,
  }) async {
    started.add(command);
    final exitCode = exitCodes[command];
    if (exitCode == null) {
      await output!.cancelled;
      stopped.add(command);
      return 143;
    }
    await Future<void>.delayed(Duration.zero);
    output
      ?..onOutput('out of $command')
      ..onError('err of $command');
    return exitCode;
  }
}

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
  Prompt? prompt,
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
    prompt: prompt ?? FakePrompt(),
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

    group(r'$parallel', () {
      const scripts = r'''
scripts:
  lint: echo lint
  test:
    $before: echo before
    $script: echo test
  wait:
    $steps:
      - echo waiting
      - echo never
  verify:
    $parallel:
      - rps lint
      - rps test
      - echo plain
  broken:
    $parallel:
      - rps wait
      - echo bad
  nested:
    $parallel:
      - rps verify
      - echo side
  ask:
    $parallel:
      - rps danger
  danger:
    $confirm: Sure?
    $script: echo danger
''';

      Future<(_ScriptedExecutor, String, String)> run(
        List<String> arguments,
        Map<String, int> exitCodes, {
        bool dryRun = false,
        bool assumeYes = false,
      }) async {
        final executor = _ScriptedExecutor(exitCodes);
        final out = StringBuffer();
        final errors = StringBuffer();
        final events = ScriptsParser(
          source: MockedScriptSource(scripts),
          platform: const FakePlatform(),
        ).getCommandsToExecute(arguments);
        try {
          await ScriptRunner(
            executor: executor,
            console: Console(sink: out, ansi: false),
            errors: Console(sink: errors, ansi: false),
            dryRun: dryRun,
            assumeYes: assumeYes,
          ).run(events);
        } finally {
          printOnFailure('$out\n$errors');
        }
        return (executor, out.toString(), errors.toString());
      }

      test('runs the branches at once and labels their output', () async {
        final (executor, out, errors) = await run(
          ['verify'],
          {'echo lint': 0, 'echo before': 0, 'echo test': 0, 'echo plain': 0},
        );

        expect(
          executor.started.take(3),
          unorderedEquals(['echo lint', 'echo before', 'echo plain']),
        );
        expect(executor.started.last, equals('echo test'));
        expect(out, startsWith('> verify (3 in parallel)\n\n'));
        expect(out, contains('[lint] > lint\n[lint] \$ echo lint\n'));
        expect(out, contains('[lint] out of echo lint\n'));
        expect(out, contains('[test] out of echo before\n'));
        expect(out, contains('[test] out of echo test\n'));
        expect(out, contains('[3   ] \$ echo plain\n'));
        expect(out, contains('[3   ] out of echo plain\n'));
        expect(errors, contains('[lint] err of echo lint\n'));
        expect(errors, isNot(contains('out of')));
      });

      test('stops the other branches at the first failure', () async {
        final executor = _ScriptedExecutor({'echo bad': 6});
        final events = ScriptsParser(
          source: MockedScriptSource(scripts),
          platform: const FakePlatform(),
        ).getCommandsToExecute(['broken']);

        await expectLater(
          ScriptRunner(
            executor: executor,
            console: Console(sink: StringBuffer()),
          ).run(events),
          throwsA(isA<ScriptFailedException>()
              .having((e) => e.exitCode, 'exitCode', 6)
              .having(
                (e) => e.message,
                'message',
                'The command "2" ended with a non zero exit code (6).',
              )),
        );
        expect(executor.stopped, equals(['echo waiting']));
        expect(executor.started, isNot(contains('echo never')));
      });

      test('labels nested branches with every level', () async {
        final (_, out, _) = await run(
          ['nested'],
          {
            'echo lint': 0,
            'echo before': 0,
            'echo test': 0,
            'echo plain': 0,
            'echo side': 0,
          },
        );

        expect(out, contains('[verify lint] out of echo lint\n'));
        expect(out, contains('[2     ] out of echo side\n'));
      });

      test('asks for the confirmations of its branches first', () async {
        await expectLater(
          run(['ask'], {'echo danger': 0}),
          throwsA(isA<RpsUsageException>()),
        );
        final (executor, _, _) = await run(
          ['ask'],
          {'echo danger': 0},
          assumeYes: true,
        );
        expect(executor.started, equals(['echo danger']));
      });

      test('prints the branches in a dry run', () async {
        final (executor, out, _) = await run(['verify'], {}, dryRun: true);

        expect(executor.started, isEmpty);
        expect(
          out,
          equals(
            '> verify (3 in parallel)\n\n'
            '[lint] > verify [1/3]\n'
            '[lint] \$ rps lint\n'
            '[lint] > lint\n'
            '[lint] \$ echo lint\n'
            '[test] > verify [2/3]\n'
            '[test] \$ rps test\n'
            '[test] > test before\n'
            '[test] \$ echo before\n'
            '[test] > test\n'
            '[test] \$ echo test\n'
            '[3   ] > verify [3/3]\n'
            '[3   ] \$ echo plain\n'
            '\n',
          ),
        );
      });
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
        final prompt = FakePrompt(['yes']);
        final run = await _run(
          scripts,
          ['all'],
          interactive: true,
          prompt: prompt,
        );

        expect(prompt.questions, equals(['Drop the database? (y/N)']));
        expect(
          run.executor.executions,
          equals(['echo first', 'echo reset', 'echo reset']),
        );
      });

      test('treats an empty answer as no', () async {
        await expectLater(
          _run(scripts, ['reset'], interactive: true, prompt: FakePrompt([''])),
          throwsA(isA<RpsException>()),
        );
      });

      test('runs nothing when the user declines', () async {
        await expectLater(
          _run(
            scripts,
            ['all'],
            interactive: true,
            prompt: FakePrompt(['n']),
          ),
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
