import 'package:rps/rps.dart';
import '../mocks/fake_platform.dart';
import 'package:test/test.dart';

import '../mocks/script_source.mock.dart';
import '../mocks/stream_sink_controller.dart';
import '../scripts_parser/scripts_parser_test.dart';

void main() {
  group('RunCommand.run', () {
    const scripts = r'''
scripts:
  run:
    dev: echo dev
  build: echo build
  start: echo start
''';

    Future<List<String>> execute(List<String> arguments) async {
      final executions = <String>[];
      final run = RunCommand(
        getScriptsSource: () => MockedScriptSource(scripts),
        executor: FakeExecutor(exitCode: 0, executions: executions),
        platform: const FakePlatform(),
      );
      await run.run(Console(sink: StringBuffer()), arguments);
      return executions;
    }

    test('strips the "run" command name', () async {
      expect(await execute(['run', 'build']), ['echo build']);
    });

    test('resolves scripts nested under a "run" key', () async {
      expect(await execute(['run', 'dev']), ['echo dev']);
      expect(await execute(['run', 'run', 'dev']), ['echo dev']);
    });

    test('reports the original error when nothing matches', () async {
      expect(
        () => execute(['run', 'missing']),
        throwsA(isA<RpsException>().having(
          (e) => e.message,
          'message',
          contains('"missing" not found'),
        )),
      );
    });
  });

  group('RunCommand dry run', () {
    const scripts = r'''
scripts:
  hello: echo hello
  greet: echo hi ${0}
  build:
    $before: echo before
    $after: echo after
    apk:
      $before: rps hello
      $script: echo apk
  alias: rps build apk
''';

    late List<String> executions;
    late StreamSinkController sink;

    Future<void> dryRun(List<String> arguments) {
      executions = [];
      sink = StreamSinkController();
      return RunCommand(
        getScriptsSource: () => MockedScriptSource(scripts),
        executor: FakeExecutor(exitCode: 1, executions: executions),
        platform: const FakePlatform(),
        dryRun: true,
      ).run(Console(sink: sink, ansi: false), arguments);
    }

    test('prints hooks and references in order and runs nothing', () async {
      await dryRun(['alias', '--release']);

      expect(executions, isEmpty);
      expect(
        sink.lines,
        equals([
          '> alias',
          r'$ rps build apk',
          '',
          '> build before',
          r'$ echo before',
          '',
          '> build apk before',
          r'$ rps hello',
          '',
          '> hello',
          r'$ echo hello',
          '',
          '> build apk',
          r'$ echo apk --release',
          '',
          '> build after',
          r'$ echo after',
          '',
        ]),
      );
    });

    test('fills positional arguments', () async {
      await dryRun(['greet', 'Bob']);
      expect(sink.lines, contains(r'$ echo hi Bob'));
    });

    test('reports missing positional arguments', () async {
      expect(() => dryRun(['greet']), throwsA(isA<RpsException>()));
    });

    test('reports a missing script', () async {
      expect(() => dryRun(['missing']), throwsA(isA<RpsException>()));
    });
  });
}
