import 'dart:io';

import 'package:rps/rps.dart';
import 'package:rps/src/models/interpreter.dart';
import 'package:yaml/yaml.dart';

/// Parsed data from the rps.yaml configuration file.
class RpsYamlData {
  /// The raw scripts map, or null if none defined.
  final Map<dynamic, dynamic>? scripts;

  /// Windows-specific interpreter configuration.
  final WindowsConfig windows;

  /// Linux-specific interpreter configuration.
  final UnixConfig linux;

  /// macOS-specific interpreter configuration.
  final UnixConfig macos;

  /// Creates an [RpsYamlData].
  const RpsYamlData({
    this.scripts,
    this.windows = const WindowsConfig(),
    this.linux = const UnixConfig(),
    this.macos = const UnixConfig(),
  });

  /// Parses an [RpsYamlData] from a YAML map.
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

/// Windows interpreter configuration.
class WindowsConfig {
  /// The interpreter to use on Windows.
  final WindowsInterpreter interpreter;

  /// Creates a [WindowsConfig] with the given [interpreter].
  const WindowsConfig({
    this.interpreter = WindowsInterpreter.powershell,
  });

  /// Parses a [WindowsConfig] from a YAML map.
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

/// Unix interpreter configuration.
class UnixConfig {
  /// The interpreter to use on Linux/macOS.
  final UnixInterpreter interpreter;

  /// Creates a [UnixConfig] with the given [interpreter].
  const UnixConfig({
    this.interpreter = UnixInterpreter.bash,
  });

  /// Parses a [UnixConfig] from a YAML map.
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

/// Extension to resolve the platform-appropriate interpreter.
extension GetInterpreter on RpsYamlData {
  /// Returns the interpreter for the current platform, or null if unsupported.
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
