import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:rps/rps.dart';
import 'package:rps/src/models/rps_yaml_data.dart';
import 'package:yaml/yaml.dart';

/// A script source implementation that loads scripts from the `rps.yaml` file.
class RpsYaml implements ScriptsSource {
  /// The expected filename.
  static const filename = 'rps.yaml';

  /// The directory containing the rps.yaml file.
  final Directory directory;

  /// The parsed YAML data.
  final RpsYamlData data;

  /// Whether scripts are defined in the file.
  bool get hasScripts => data.scripts != null;

  RpsYaml._(this.directory, this.data);

  /// Returns `true` if the `rps.yaml` file
  /// is present in the provided [directory].
  static bool exists(Directory directory) {
    final filePath = p.join(directory.path, filename);
    final rpsFile = File(filePath);
    return rpsFile.existsSync();
  }

  /// Loads and parses the rps.yaml from [directory].
  factory RpsYaml.load(Directory directory) {
    bool isScriptsFile(File file) => p.basename(file.path) == RpsYaml.filename;

    final file = directory.listSync().whereType<File>().firstWhere(
          isScriptsFile,
          orElse: () => throw RpsException(
            'Cannot find $filename file in the current directory '
            '(${Directory.current.path}).',
          ),
        );

    try {
      final string = file.readAsStringSync();
      final parsed = loadYaml(string);
      final data = RpsYamlData.fromYaml(parsed);

      return RpsYaml._(directory, data);
    } on RpsException {
      rethrow;
    } on Exception catch (err, st) {
      throw RpsException('The rps.yaml file cannot be parsed.', err, st);
    }
  }

  @override
  dynamic getScripts() {
    final scripts = data.scripts;
    if (scripts == null) {
      throw RpsException('Missing scripts in the $filename file.');
    }
    return scripts;
  }
}
