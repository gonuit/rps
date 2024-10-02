import 'dart:io';

import 'package:rps/rps.dart';
import 'package:rps/src/models/interpreter.dart';
import 'package:yaml/yaml.dart';

class RpsYamlData {
  final Map<dynamic, dynamic>? scripts;
  final WindowsConfig windows;
  final UnixConfig linux;
  final UnixConfig macos;

  const RpsYamlData({
    this.scripts,
    this.windows = const WindowsConfig(),
    this.linux = const UnixConfig(),
    this.macos = const UnixConfig(),
  });

  factory RpsYamlData.fromYaml(YamlMap yaml) => RpsYamlData(
        scripts: yaml['scripts'] == null
            ? null
            : Map.unmodifiable(yaml['scripts']) as Map<dynamic, dynamic>?,
        windows: yaml['windows'] == null
            ? const WindowsConfig()
            : WindowsConfig.fromYaml(yaml['windows']),
        linux: yaml['linux'] == null
            ? const UnixConfig()
            : UnixConfig.fromYaml(yaml['linux']),
        macos: yaml['macos'] == null
            ? const UnixConfig()
            : UnixConfig.fromYaml(yaml['macos']),
      );
}

class WindowsConfig {
  final WindowsInterpreter interpreter;

  const WindowsConfig({
    this.interpreter = WindowsInterpreter.powershell,
  });

  factory WindowsConfig.fromYaml(YamlMap json) => WindowsConfig(
        interpreter: json['interpreter'] == null
            ? WindowsInterpreter.powershell
            : WindowsInterpreter.values.firstWhere(
                (i) => i.value == json['interpreter'],
                orElse: () => throw RpsException(
                  'Provided Windows interpreter (${json['interpreter']}) '
                  'is not supported. '
                  'Supported values are: '
                  '${WindowsInterpreter.values.map((i) => '"${i.name}"').join(', ')}.',
                ),
              ),
      );
}

class UnixConfig {
  final UnixInterpreter interpreter;

  const UnixConfig({
    this.interpreter = UnixInterpreter.bash,
  });

  factory UnixConfig.fromYaml(YamlMap json) => UnixConfig(
        interpreter: json['interpreter'] == null
            ? UnixInterpreter.bash
            : UnixInterpreter.values.firstWhere(
                (i) => i.value == json['interpreter'],
                orElse: () => throw RpsException(
                  'Provided Unix interpreter (${json['interpreter']}) is not '
                  'supported. '
                  'Supported values are: '
                  '${UnixInterpreter.values.map((i) => '"${i.name}"').join(', ')}.',
                ),
              ),
      );
}

extension GetInterpreter on RpsYamlData {
  Interpreter? get interpreter {
    if (Platform.isWindows) {
      return windows.interpreter;
    } else if (Platform.isMacOS) {
      return macos.interpreter;
    } else if (Platform.isLinux) {
      return linux.interpreter;
    } else {
      return null;
    }
  }
}
