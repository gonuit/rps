import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:rps/rps_exception.dart';
import 'package:yaml/yaml.dart';

class ScriptContext {
  final Map scripts;
  final List<String> arguments;
  final List<String> path;
  String get stringPath => path.join(' ');

  List<String> get rest => arguments.sublist(position + 1);

  final int position;
  String get command => arguments[position];
  dynamic get script => scripts[command];

  bool get hasMoreArguments => position + 1 < arguments.length;

  ScriptContext(
      {required Map scripts,
      required List<String> arguments,
      List<String>? path,
      this.position = 0})
      : arguments = List.unmodifiable(arguments),
        path = List.unmodifiable(path ?? [arguments[position]]),
        scripts = Map.unmodifiable(scripts);

  ScriptContext next() {
    if (position + 1 >= arguments.length) {
      throw StateError("No more commands.");
    }

    final nextPosition = position + 1;
    final nextCommand = arguments[nextPosition];

    return ScriptContext(
      scripts: script,
      arguments: arguments,
      position: nextPosition,
      path: [...path, nextCommand],
    );
  }
}

abstract class PubspecCommand {
  final String path;
  final String? command;

  /// Whether this command should be executed
  bool get executable;

  PubspecCommand(this.path, this.command);

  @override
  bool operator ==(Object other) {
    return other is PubspecCommand &&
        other.command == command &&
        other.path == path;
  }

  @override
  int get hashCode => Object.hash(path, command, runtimeType);
}

class ExecutableCommand extends PubspecCommand {
  @override
  bool get executable => true;

  ExecutableCommand(super.path, super.command);

  @override
  bool operator ==(Object other) {
    return other is ExecutableCommand &&
        other.command == command &&
        other.path == path;
  }

  @override
  int get hashCode => Object.hash(path, command, runtimeType);

  @override
  String toString() => 'ExecutableCommand("$path": "$command")';
}

/// Indicates that reference was made to the command
class RefCommand extends PubspecCommand {
  RefCommand(String path) : super(path, null);

  /// This command is only a trace mark, nothing to call here.
  @override
  bool get executable => false;

  @override
  bool operator ==(Object other) {
    return other is RefCommand &&
        other.command == command &&
        other.path == path;
  }

  @override
  int get hashCode => Object.hash(path, runtimeType);

  @override
  String toString() => 'HookCommand("$path")';
}

class Pubspec {
  static const filename = 'pubspec.yaml';

  final Directory directory;
  final Map parsed;

  static const beforeKey = r'$before';
  static const afterKey = r'$after';
  static const scriptKey = r'$script';
  static const defaultScriptKey = r'$default';

  Pubspec._(this.directory, this.parsed);

  static Future<Pubspec> load(Directory directory) async {
    bool isPubspecFile(File file) => p.basename(file.path) == Pubspec.filename;

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

  Iterable<PubspecCommand> getCommands(
    List<String> args,
  ) sync* {
    var scripts = parsed['scripts'];
    if (scripts == null) {
      throw RpsException('Missing "scripts" field in the pubspec.yaml file.');
    }

    final arguments = args.isNotEmpty ? args : ['run'];

    final context = ScriptContext(
      arguments: arguments,
      scripts: scripts,
    );

    yield* _getCommands(
      context: context,
    );
  }

  Iterable<PubspecCommand> _getCommands({
    required ScriptContext context,
  }) sync* {
    final value = context.script;

    if (value == null) {
      throw RpsException(
        'Missing script for: "${context.stringPath}".',
      );
    } else if (value is String) {
      yield* _examinateCommand(
        command: [value, ...context.rest].join(' '),
        path: context.stringPath,
      );
    } else if (value is Map) {
      yield* _getHookCommands(
        key: beforeKey,
        scripts: value,
        context: context,
      );

      if (_hasScriptKey(value)) {
        final script = value[scriptKey];
        if (script is String) {
          yield* _examinateCommand(command: script, path: context.stringPath);
        } else if (script is Map) {
          final platformKey = '\$${Platform.operatingSystem}';
          final command = script[platformKey] ?? script[defaultScriptKey];
          if (command is! String) {
            throw RpsException(
              'No platform script key for the command: '
              '"${context.stringPath}". '
              'Consider adding the key for the current '
              'platform: "$platformKey" or the default script '
              'key: "$defaultScriptKey".',
            );
          } else {
            yield* _examinateCommand(
              command: command,
              path: [context.stringPath, ...context.rest].join(' '),
            );
          }
        }
      } else if (context.hasMoreArguments) {
        yield* _getCommands(context: context.next());
      } else {
        throw RpsException(
          'Missing script. Command: "${context.stringPath}" '
          'is not a full path.',
        );
      }

      yield* _getHookCommands(
        key: afterKey,
        scripts: value,
        context: context,
      );
    } else {
      throw RpsException(
        'Invalid command. Cannot use type '
        '${value.runtimeType} ($value) as a command.',
      );
    }
  }

  Iterable<PubspecCommand> _examinateCommand({
    required String command,
    required String path,
  }) sync* {
    if (command.startsWith(r'$')) {
      yield RefCommand(path);
      yield* getCommands(command.substring(1).split(RegExp(r'\s+')));
    } else {
      yield ExecutableCommand(path, command);
    }
  }

  Iterable<PubspecCommand> _getHookCommands({
    required Map scripts,
    required String key,
    required ScriptContext context,
  }) sync* {
    final value = scripts[key];
    if (value == null) {
      /// No hook command
      return;
    } else if (value is! String) {
      throw RpsException(
        'Invalid "$key" value. '
        'Only a command (String) can be specified as hook.',
      );
    } else {
      yield* _examinateCommand(
        path: [...context.path, key].join(' '),
        command: value,
      );
    }
  }

  bool _hasScriptKey(Map scripts) {
    return scripts.keys.any((key) => key == scriptKey);
  }
}
