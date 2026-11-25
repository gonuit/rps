import 'package:rps/rps.dart';
import '../mocks/fake_platform.dart';
import 'package:test/test.dart';

import '../mocks/script_source.mock.dart';
import '../scripts_parser/scripts_parser_test.dart';

void main() {
  group('RunCommand.match', () {
    final run = RunCommand(
      getScriptsSource: () => MockedScriptSource(mockedPubspecYaml),
      executor: FakeExecutor(exitCode: 0, executions: []),
      platform: const FakePlatform(),
    );

    test('matches when arguments are provided', () {
      expect(run.match(['echo']), isTrue);
      expect(run.match(['build', 'android']), isTrue);
    });

    test('does not match when arguments are empty', () {
      expect(run.match([]), isFalse);
    });
  });

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
}
