import 'package:path/path.dart' as p;
import 'package:rps/rps.dart';
import 'package:rps/src/models/rps_yaml_data.dart';
import 'package:rps/src/utils/file_system.dart';
import 'package:yaml/yaml.dart';

/// A script source implementation that loads scripts from the `rps.yaml` file.
class RpsYaml implements ScriptsSource {
  /// The expected filename.
  static const filename = 'rps.yaml';

  /// The directory path containing the rps.yaml file.
  final String directoryPath;

  /// The parsed YAML data.
  final RpsYamlData data;

  /// Whether scripts are defined in the file.
  bool get hasScripts => data.scripts != null;

  RpsYaml._(this.directoryPath, this.data);

  /// Returns `true` if the `rps.yaml` file
  /// is present in the provided [directoryPath].
  static bool exists(
    String directoryPath, {
    required FileSystem fs,
  }) {
    final filePath = p.join(directoryPath, filename);
    return fs.fileExists(filePath);
  }

  /// Loads and parses the rps.yaml from [directoryPath].
  factory RpsYaml.load(
    String directoryPath, {
    required FileSystem fs,
  }) {
    final rpsPath = p.join(directoryPath, filename);

    if (!fs.fileExists(rpsPath)) {
      throw RpsException(
        'Cannot find $filename file in the current directory '
        '($directoryPath).',
      );
    }

    try {
      final string = fs.readFile(rpsPath);
      final parsed = loadYaml(string);
      final data = RpsYamlData.fromYaml(parsed);

      return RpsYaml._(directoryPath, data);
    } on RpsException {
      rethrow;
    } catch (err, st) {
      throw RpsException(
        'The rps.yaml file cannot be parsed. $err',
        err is Exception ? err : null,
        st,
      );
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
