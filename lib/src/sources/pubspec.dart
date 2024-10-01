import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:rps/rps.dart';
import 'package:yaml/yaml.dart';

class Pubspec implements ScriptsSource {
  static const filename = 'pubspec.yaml';

  final Directory directory;
  final Map parsed;

  Pubspec._(this.directory, this.parsed);

  factory Pubspec.load(Directory directory) {
    bool isPubspecFile(File file) => p.basename(file.path) == Pubspec.filename;

    final pubspecFile = directory.listSync().whereType<File>().firstWhere(
          isPubspecFile,
          orElse: () => throw RpsException(
            'Cannot find $filename file in the current directory '
            '(${Directory.current.path}).',
          ),
        );

    try {
      final pubspecString = pubspecFile.readAsStringSync();
      final parsed = Map.unmodifiable(loadYaml(pubspecString));

      return Pubspec._(directory, parsed);
    } on Exception catch (err, st) {
      throw RpsException('Pubspec file cannot be parsed', err, st);
    }
  }

  String get packageVersion => parsed['version']!;
  String get packageName => parsed['name']!;

  @override
  dynamic getScripts() {
    dynamic scripts = parsed['scripts'];
    if (scripts == null) {
      throw RpsException('Missing "scripts" field in the $filename file.');
    }
    return scripts;
  }
}
