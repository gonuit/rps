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
          run.executor.workingDirectories,
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
