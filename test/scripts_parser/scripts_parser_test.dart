import 'package:rps/rps.dart';
import 'package:rps/src/cli/executor.dart';
import 'package:test/test.dart';

import '../mocks/fake_file_system.dart';
import '../mocks/fake_platform.dart';
import '../mocks/script_source.mock.dart';
import '../mocks/stream_sink_controller.dart';

const mockedPubspecYaml = r'''
name: my_package
version: 3.1.0
scripts:
  echo: echo "echo 123"
  hook-1:
    $before: echo "before hook-1"
    $script: echo "hook-1"
    $after: echo "after hook-1"
  hook-2:
    $before: echo "before hook-2"
    hook-2-nested:
      $before: echo "before hook-2-nested"
      $script: echo "hook-2-nested"
      $after: echo "after hook-2-nested"
    $after: echo "after hook-2"
  ref: rps echo
  hook-ref:
    $before: rps echo
    $script: echo "hook-ref"
    $after: rps echo
  echo-args: echo
  echo-args-nested:
    echo: echo
  echo-args-hooks:
    $before: echo
    echo:
      $before: echo
      $script: echo
      $after: echo
    $after: echo
  echo-positional: echo 1=${1} 0=${0}
  echo-ref: rps echo-positional
  echo-hook-positional:
    $before: echo ${0}
    $script: echo ${0}
    $after: echo ${0}

''';

class FakeExecutor extends Executor {
  FakeExecutor({required this.exitCode, required this.executions})
      : super(
          interpreter: null,
          platform: const FakePlatform(),
          fs: FakeFileSystem(),
        );

  final int exitCode;
  final List<String> executions;

  @override
  Future<int> execute(String command) async {
    executions.add(command);
    return exitCode;
  }
}

void main() {
  final consoleSink = StreamSinkController();
  final executions = <String>[];

  setUp(() {
    executions.clear();
    consoleSink.clear();
  });

  group('run command', () {
    final run = RunCommand(
      getScriptsSource: () => MockedScriptSource(mockedPubspecYaml),
      executor: FakeExecutor(exitCode: 0, executions: executions),
      platform: const FakePlatform(),
    );

    test('Correctly executes command', () async {
      await run.run(Console(sink: consoleSink), ['echo']);
      expect(executions, equals(['echo "echo 123"']));
      expect(
        consoleSink.plainLines,
        equals([
          '> echo',
          '\$ echo "echo 123"',
          '',
          '',
        ]),
      );
    });

    test('Correctly executes hooks', () async {
      await run.run(Console(sink: consoleSink), ['hook-1']);
      expect(
        executions,
        equals([
          'echo "before hook-1"',
          'echo "hook-1"',
          'echo "after hook-1"',
        ]),
      );
      expect(
        consoleSink.plainLines,
        equals([
          '> hook-1 before',
          '\$ echo "before hook-1"',
          '',
          '',
          '> hook-1',
          '\$ echo "hook-1"',
          '',
          '',
          '> hook-1 after',
          '\$ echo "after hook-1"',
          '',
          '',
        ]),
      );
    });

    test('Correctly executes nested hooks', () async {
      await run.run(Console(sink: consoleSink), ['hook-2', 'hook-2-nested']);
      expect(
        executions,
        equals([
          'echo "before hook-2"',
          'echo "before hook-2-nested"',
          'echo "hook-2-nested"',
          'echo "after hook-2-nested"',
          'echo "after hook-2"'
        ]),
      );
      expect(
        consoleSink.plainLines,
        equals([
          '> hook-2 before',
          '\$ echo "before hook-2"',
          '',
          '',
          '> hook-2 hook-2-nested before',
          '\$ echo "before hook-2-nested"',
          '',
          '',
          '> hook-2 hook-2-nested',
          '\$ echo "hook-2-nested"',
          '',
          '',
          '> hook-2 hook-2-nested after',
          '\$ echo "after hook-2-nested"',
          '',
          '',
          '> hook-2 after',
          '\$ echo "after hook-2"',
          '',
          '',
        ]),
      );
    });

    test('Correctly executes referenced command', () async {
      await run.run(Console(sink: consoleSink), ['ref']);
      expect(
        executions,
        equals(['echo "echo 123"']),
      );
      expect(
        consoleSink.plainLines,
        equals([
          '> ref',
          '\$ rps echo',
          '',
          '> echo',
          '\$ echo "echo 123"',
          '',
          '',
        ]),
      );
    });

    test('Correctly executes references in hooks', () async {
      await run.run(
        Console(sink: consoleSink),
        ['hook-ref'],
      );
      expect(
        executions,
        equals([
          'echo "echo 123"',
          'echo "hook-ref"',
          'echo "echo 123"',
        ]),
      );
      expect(
        consoleSink.plainLines,
        equals([
          '> hook-ref before',
          '\$ rps echo',
          '',
          '> echo',
          '\$ echo "echo 123"',
          '',
          '',
          '> hook-ref',
          '\$ echo "hook-ref"',
          '',
          '',
          '> hook-ref after',
          '\$ rps echo',
          '',
          '> echo',
          '\$ echo "echo 123"',
          '',
          '',
        ]),
      );
    });

    test('Correctly pass additional arguments and options', () async {
      await run.run(
        Console(sink: consoleSink),
        ['echo-args', '123', '-v', '--help'],
      );
      expect(
        executions,
        equals([
          'echo 123 -v --help',
        ]),
      );
      expect(
        consoleSink.plainLines,
        equals([
          '> echo-args',
          '\$ echo 123 -v --help',
          '',
          '',
        ]),
      );
    });

    test('Correctly pass additional arguments and options to nested scripts',
        () async {
      await run.run(
        Console(sink: consoleSink),
        ['echo-args-nested', 'echo', '123', '-v', '--help'],
      );
      expect(
        executions,
        equals([
          'echo 123 -v --help',
        ]),
      );
      expect(
        consoleSink.plainLines,
        equals([
          '> echo-args-nested echo',
          '\$ echo 123 -v --help',
          '',
          '',
        ]),
      );
    });

    test('Do not pass arguments to hooks', () async {
      await run.run(
        Console(sink: consoleSink),
        ['echo-args-hooks', 'echo', '123', '-v', '--help'],
      );
      expect(
        executions,
        equals([
          'echo',
          'echo',
          'echo 123 -v --help',
          'echo',
          'echo',
        ]),
      );
      expect(
        consoleSink.plainLines,
        equals([
          '> echo-args-hooks before',
          '\$ echo',
          '',
          '',
          '> echo-args-hooks echo before',
          '\$ echo',
          '',
          '',
          '> echo-args-hooks echo',
          '\$ echo 123 -v --help',
          '',
          '',
          '> echo-args-hooks echo after',
          '\$ echo',
          '',
          '',
          '> echo-args-hooks after',
          '\$ echo',
          '',
          ''
        ]),
      );
    });

    test('Correctly pass positional arguments', () async {
      await run.run(
        Console(sink: consoleSink),
        ['echo-positional', 'zero', 'one'],
      );
      expect(
        executions,
        equals([
          'echo 1=one 0=zero',
        ]),
      );
      expect(
        consoleSink.plainLines,
        equals([
          '> echo-positional',
          '\$ echo 1=one 0=zero',
          '',
          '',
        ]),
      );
    });

    test('Pass positional arguments to references', () async {
      await run.run(
        Console(sink: consoleSink),
        ['echo-ref', 'zero', 'one'],
      );
      expect(
        executions,
        equals([
          'echo 1=one 0=zero',
        ]),
      );
      expect(
        consoleSink.plainLines,
        equals([
          '> echo-ref',
          '\$ rps echo-positional',
          '',
          '> echo-positional',
          '\$ echo 1=one 0=zero',
          '',
          '',
        ]),
      );
    });

    test('Throw error when positional arguments are passed to hooks.',
        () async {
      RpsException? exception;
      try {
        await run.run(
          Console(sink: consoleSink),
          ['echo-hook-positional', 'zero'],
        );
      } on RpsException catch (err) {
        exception = err;
      }

      expect(exception, isNotNull);
      expect(
        exception!.message,
        r'The script "echo-hook-positional $before" defines a positional argument(s), but hooks do not support positional arguments.',
      );
      expect(
        executions,
        equals([]),
      );
      expect(
        consoleSink.plainLines,
        equals([
          '> echo-hook-positional before',
        ]),
      );
    });
  });
}
