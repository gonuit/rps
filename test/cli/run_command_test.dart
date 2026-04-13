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
}
