import 'package:path/path.dart' as p;
import 'package:rps/rps.dart';
import 'package:rps/src/utils/file_system.dart';
import 'package:yaml/yaml.dart';

/// A [ScriptsSource] that reads scripts from `pubspec.yaml`.
class Pubspec implements ScriptsSource {
  /// The expected filename.
  static const filename = 'pubspec.yaml';

  /// The directory path containing the pubspec file.
  final String directoryPath;

  /// The parsed YAML content.
  final Map parsed;

  Pubspec._(this.directoryPath, this.parsed);

  /// Loads and parses the pubspec.yaml from [directoryPath].
  factory Pubspec.load(
    String directoryPath, {
    required FileSystem fs,
  }) {
    final pubspecPath = p.join(directoryPath, filename);

    if (!fs.fileExists(pubspecPath)) {
      throw RpsException(
        'Cannot find $filename file in the current directory '
        '($directoryPath).',
      );
    }

    try {
      final pubspecString = fs.readFile(pubspecPath);
      final parsed = Map.unmodifiable(loadYaml(pubspecString));

      return Pubspec._(directoryPath, parsed);
    } on Exception catch (err, st) {
      throw RpsException('Pubspec file cannot be parsed', err, st);
    }
  }

  /// The package version from pubspec.yaml.
  String get packageVersion => parsed['version']!;

  /// The package name from pubspec.yaml.
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
