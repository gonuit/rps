import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:rps/rps.dart';
import 'package:yaml/yaml.dart';

/// A script source implementation that loads scripts from the `rps.yaml` file.
class RpsYaml implements ScriptsSource {
  static const filename = 'rps.yaml';

  final Directory directory;
  final Map parsed;

  RpsYaml._(this.directory, this.parsed);

  /// Returns `true` if the `rps.yaml` file
  /// is present in the provided [directory].
  static bool exists(Directory directory) {
    final filePath = p.join(directory.path, filename);
    final rpsFile = File(filePath);
    return rpsFile.existsSync();
  }

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
      final parsed = Map.unmodifiable(loadYaml(string));

      return RpsYaml._(directory, parsed);
    } on Exception catch (err, st) {
      throw RpsException('Scripts file cannot be parsed', err, st);
    }
  }

  @override
  dynamic getScripts() {
    dynamic scripts = parsed['scripts'];
    if (scripts == null) {
      throw RpsException('Missing scripts in the $filename file.');
    }
    return scripts;
  }
}
