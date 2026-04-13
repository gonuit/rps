import 'package:rps/rps.dart';
import 'package:rps/src/models/interpreter.dart';
import 'package:rps/src/models/rps_yaml_data.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../mocks/fake_platform.dart';

void main() {
  group('RpsYamlData', () {
    test('defaults have no scripts', () {
      const data = RpsYamlData();
      expect(data.scripts, isNull);
    });

    test('fromYaml parses scripts', () {
      final yaml = loadYaml('scripts:\n  test: echo hi\n') as YamlMap;
      final data = RpsYamlData.fromYaml(yaml);
      expect(data.scripts, isNotNull);
      expect(data.scripts!['test'], equals('echo hi'));
    });

    test('fromYaml parses windows config', () {
      final yaml = loadYaml('windows:\n  interpreter: cmd\n') as YamlMap;
      final data = RpsYamlData.fromYaml(yaml);
      expect(data.windows.interpreter, equals(WindowsInterpreter.cmd));
    });

    test('fromYaml parses linux config', () {
      final yaml = loadYaml('linux:\n  interpreter: zsh\n') as YamlMap;
      final data = RpsYamlData.fromYaml(yaml);
      expect(data.linux.interpreter, equals(UnixInterpreter.zsh));
    });

    test('fromYaml parses macos config', () {
      final yaml = loadYaml('macos:\n  interpreter: zsh\n') as YamlMap;
      final data = RpsYamlData.fromYaml(yaml);
      expect(data.macos.interpreter, equals(UnixInterpreter.zsh));
    });

    test('throws on invalid windows interpreter', () {
      final yaml = loadYaml('windows:\n  interpreter: invalid\n') as YamlMap;
      expect(
        () => RpsYamlData.fromYaml(yaml),
        throwsA(isA<RpsException>()),
      );
    });

    test('throws on invalid unix interpreter', () {
      final yaml = loadYaml('linux:\n  interpreter: invalid\n') as YamlMap;
      expect(
        () => RpsYamlData.fromYaml(yaml),
        throwsA(isA<RpsException>()),
      );
    });
  });

  group('GetInterpreter', () {
    test('returns windows interpreter on windows', () {
      const data = RpsYamlData(
        windows: WindowsConfig(interpreter: WindowsInterpreter.cmd),
      );
      final result = data.getInterpreter(const FakePlatform.windows());
      expect(result, equals(WindowsInterpreter.cmd));
    });

    test('returns macos interpreter on macos', () {
      const data = RpsYamlData(
        macos: UnixConfig(interpreter: UnixInterpreter.zsh),
      );
      final result = data.getInterpreter(const FakePlatform());
      expect(result, equals(UnixInterpreter.zsh));
    });

    test('returns linux interpreter on linux', () {
      const data = RpsYamlData(
        linux: UnixConfig(interpreter: UnixInterpreter.sh),
      );
      final result = data.getInterpreter(const FakePlatform.linux());
      expect(result, equals(UnixInterpreter.sh));
    });

    test('returns null on unsupported platform', () {
      const data = RpsYamlData();
      const platform = FakePlatform(
        isWindows: false,
        isMacOS: false,
        isLinux: false,
        operatingSystem: 'fuchsia',
      );
      expect(data.getInterpreter(platform), isNull);
    });
  });

  group('WindowsConfig', () {
    test('defaults to powershell', () {
      const config = WindowsConfig();
      expect(config.interpreter, equals(WindowsInterpreter.powershell));
    });
  });

  group('UnixConfig', () {
    test('defaults to bash', () {
      const config = UnixConfig();
      expect(config.interpreter, equals(UnixInterpreter.bash));
    });
  });
}
