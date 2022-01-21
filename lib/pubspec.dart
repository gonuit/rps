import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:rps/rps_exception.dart';
import 'package:yaml/yaml.dart';

class PubspecCommand {
  final String path;
  final String? command;

  PubspecCommand(this.path, this.command);
}

class Pubspec {
  static const filename = 'pubspec.yaml';

  final Directory directory;
  final Map parsed;

  Pubspec._(this.directory, this.parsed);

  static Future<Pubspec> load(Directory directory) async {
    bool isPubspecFile(File file) =>
        path.basename(file.path) == Pubspec.filename;

    final pubspecFile = await directory
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .firstWhere(
          isPubspecFile,
          orElse: () => throw RpsException(
            'Cannot find pubspec.yaml file in the current directory '
            '(${Directory.current.path}).',
          ),
        );

    try {
      final pubspecString = await pubspecFile.readAsString();
      final parsed = Map.unmodifiable(loadYaml(pubspecString));

      return Pubspec._(directory, parsed);
    } on Exception catch (err, st) {
      throw RpsException('Pubspec file cannot be parsed', err, st);
    }
  }

  String? get packageVersion => parsed['version'];
  String? get packageName => parsed['name'];

  PubspecCommand getCommand(
    List<String> args, {
    bool before = false,
    bool after = false,
  }) {
    if (before && after) {
      throw ArgumentError(
        'Cannot return before and after commands at the same time.',
      );
    }
    final arguments = args.isNotEmpty ? args : ['run'];

    var scripts = parsed['scripts'];
    if (scripts == null) {
      throw RpsException('Missing "scripts" field in the pubspec.yaml file.');
    }

    for (var i = 0; i < arguments.length; i++) {
      final arg = arguments[i];
      final value = scripts[arg];

      if (value == null) {
        throw RpsException(
          'Missing script for: "${[...arguments.take(i), arg].join(' ')}".',
        );
      } else if (value is Map) {
        scripts = value;
        continue;
      } else if (value is String) {
        final rest = arguments.sublist(i + 1);
        if (before) {
          final key = 'before-$arg';
          return PubspecCommand(
            [...arguments.take(i), key].join(' '),
            _getHookCommand(scripts, key, rest),
          );
        } else if (after) {
          final key = 'after-$arg';
          return PubspecCommand(
            [...arguments.take(i), key].join(' '),
            _getHookCommand(scripts, key, rest),
          );
        } else {
          return PubspecCommand(
            arguments.take(i + 1).join(' '),
            [value, ...rest].join(' '),
          );
        }
      } else {
        throw RpsException(
          'Invalid command. Cannot use type '
          '${value.runtimeType} ($value) as a command.',
        );
      }
    }

    throw RpsException(
      'Missing script. Command: "${arguments.join(' ')}" '
      'is not a full path.',
    );
  }

  String? _getHookCommand(Map scripts, String command, List<String> rest) {
    final hookCommand = scripts[command];
    if (hookCommand == null) {
      return null;
    } else if (hookCommand is String) {
      return [hookCommand, ...rest].join(' ');
    } else {
      throw RpsException('Incorrect value of "$command" command.');
    }
  }
}
