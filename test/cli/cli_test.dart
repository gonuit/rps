import 'package:rps/rps.dart';
import 'package:rps/src/cli/cli.dart';
import 'package:rps/src/cli/cli_options/cli_option.dart';
import 'package:rps/src/cli/exceptions/cli_exception.dart';
import '../mocks/fake_platform.dart';
import '../mocks/fake_rps_package.dart';
import 'package:test/test.dart';

import '../mocks/stream_sink_controller.dart';
import '../mocks/script_source.mock.dart';
import '../scripts_parser/scripts_parser_test.dart';

class _FakeOption extends CliOption {
  bool ran = false;
  @override
  String get description => 'fake';
  @override
  String get name => 'fake';
  @override
  String? get short => 'f';
  @override
  Future<void> run(Cli cli, Console console, List<String> arguments) async {
    ran = true;
  }
}

void main() {
  late StreamSinkController sink;
  late Console console;
  late List<String> executions;

  setUp(() {
    sink = StreamSinkController();
    console = Console(sink: sink);
    executions = [];
  });

  group('Cli', () {
    test('throws CliException when no command matches and no fallback', () {
      final cli = Cli(
        package: createFakeRpsPackage(),
        console: console,
        commands: [
          RunCommand(
            getScriptsSource: () => MockedScriptSource(mockedPubspecYaml),
            executor: FakeExecutor(exitCode: 0, executions: executions),
            platform: const FakePlatform(),
          ),
        ],
        options: [],
        fallback: null,
      );

      expect(
        () => cli.run([]),
        throwsA(isA<CliException>()),
      );
    });

    test('runs matched command', () async {
      final cli = Cli(
        package: createFakeRpsPackage(),
        console: console,
        commands: [
          RunCommand(
            getScriptsSource: () => MockedScriptSource(mockedPubspecYaml),
            executor: FakeExecutor(exitCode: 0, executions: executions),
            platform: const FakePlatform(),
          ),
        ],
        options: [],
        fallback: null,
      );

      await cli.run(['echo']);
      expect(executions, equals(['echo "echo 123"']));
    });

    test('runs matched option', () async {
      final option = _FakeOption();
      final cli = Cli(
        package: createFakeRpsPackage(),
        console: console,
        commands: [],
        options: [option],
        fallback: null,
      );

      await cli.run(['--fake']);
      expect(option.ran, isTrue);
    });

    test('runs fallback when no command or option matches', () async {
      final fallback = _FakeOption();
      final cli = Cli(
        package: createFakeRpsPackage(),
        console: console,
        commands: [],
        options: [],
        fallback: fallback,
      );

      await cli.run([]);
      expect(fallback.ran, isTrue);
    });
  });
}
