import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:rps/rps.dart';
import 'package:yaml/yaml.dart';

class ScriptsYaml implements ScriptsSource {
  static const filename = 'scripts.yaml';

  final Directory directory;
  final Map parsed;

  ScriptsYaml._(this.directory, this.parsed);

  factory ScriptsYaml.load(Directory directory) {
    bool isScriptsFile(File file) => p.basename(file.path) == ScriptsYaml.filename;

    final file = directory.listSync().whereType<File>().firstWhere(
          isScriptsFile,
          orElse: () => throw RpsException(
            'Cannot find scripts.yaml file in the current directory '
            '(${Directory.current.path}).',
          ),
        );

    try {
      final string = file.readAsStringSync();
      final parsed = Map.unmodifiable(loadYaml(string));

      return ScriptsYaml._(directory, parsed);
    } on Exception catch (err, st) {
      throw RpsException('Scripts file cannot be parsed', err, st);
    }
  }

  @override
  dynamic getScripts() {
    dynamic scripts = parsed;
    if (scripts == null) {
      throw RpsException('Missing scripts in the scripts.yaml file.');
    }
    return scripts;
  }
}
