import 'dart:io';
import 'dart:math' as math;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'exceptions/rps_exception.dart';

class ScriptContext {
  final Map scripts;
  final List<String> arguments;
  final List<String> path;
  String get stringPath => path.join(' ');

  /// List of remaining arguments
  List<String> get rest => arguments.sublist(position + 1);

  final int position;
  String get command => arguments[position];
  dynamic get script => scripts[command];

  bool get hasMoreArguments => position + 1 < arguments.length;

  ScriptContext({
    required Map scripts,
    required List<String> arguments,
    List<String>? path,
    this.position = 0,
  })  : arguments = List.unmodifiable(arguments),
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

@immutable
abstract class PubspecCommand {
  String get path;
  String? get command;

  /// Whether this command should be executed
  bool get executable;
}

class PositionalArgument {
  final int position;
  final int start;
  final int end;

  PositionalArgument(this.position, this.start, this.end);
}

class ExecutableCommand extends PubspecCommand {
  @override
  bool get executable => true;

  @override
  final String command;
  @override
  final String path;

  static final _positionalArgumentsRegexp = RegExp(r'\$\{\s{0,}[0-9]+\s{0,}\}');

  ExecutableCommand._(this.command, this.path);

  factory ExecutableCommand(
    String path,
    String command, [
    List<String> rest = const <String>[],
  ]) {
    final argumentsInCommand = _positionalArgumentsRegexp.allMatches(command);

    if (argumentsInCommand.isNotEmpty) {
      final usedArguments = <int>{};
      final filledCommand = command.replaceAllMapped(
        _positionalArgumentsRegexp,
        (match) {
          final content = match.group(0)!;
          final value = content.substring(2, content.length - 1).trim();
          final argumentIndex = int.tryParse(value);
          if (argumentIndex == null) {
            throw RpsException(
              "Bad argument script ($content). "
              "Only positional arguments are supported.",
            );
          } else if (argumentIndex >= rest.length) {
            throw RpsException(
              'The script "$path" defines a positional argument $content, '
              'but ${rest.length} positional argument(s) are given.',
            );
          } else {
            usedArguments.add(argumentIndex);
            return rest[argumentIndex];
          }
        },
      );

      final lastUsed = usedArguments.reduce(math.max);
      if (lastUsed > usedArguments.length) {
        final unusedArguments = List<int>.generate(lastUsed, (index) => index)
            .where((e) => !usedArguments.contains(e));

        throw RpsException(
          'The script defines unused positional argument(s): '
          '${unusedArguments.map((a) => '\${$a}').join(', ')}',
        );
      }

      return ExecutableCommand._(
        [filledCommand, ...rest.sublist(lastUsed + 1)].join(' '),
        path,
      );
    } else {
      return ExecutableCommand._([command, ...rest].join(' '), path);
    }
  }

  @override
  bool operator ==(Object other) {
    return other is ExecutableCommand &&
        other.command == command &&
        other.path == path;
  }

  @override
  int get hashCode => Object.hash(path, command, runtimeType);
}

/// Indicates that reference was made to the command
class RefCommand extends PubspecCommand {
  /// This command is only a trace mark, nothing to call here.
  @override
  bool get executable => false;

  @override
  Null get command => null;

  @override
  final String path;

  RefCommand(this.path);

  @override
  bool operator ==(Object other) {
    return other is RefCommand &&
        other.command == command &&
        other.path == path;
  }

  @override
  int get hashCode => Object.hash(path, command, runtimeType);
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

  factory Pubspec.load(Directory directory) {
    bool isPubspecFile(File file) => p.basename(file.path) == Pubspec.filename;

    final pubspecFile = directory.listSync().whereType<File>().firstWhere(
          isPubspecFile,
          orElse: () => throw RpsException(
            'Cannot find pubspec.yaml file in the current directory '
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
        command: value,
        path: context.stringPath,
        rest: context.rest,
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
          yield* _examinateCommand(
            command: script,
            path: context.stringPath,
            rest: context.rest,
          );
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
              path: context.stringPath,
              rest: context.rest,
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
    List<String> rest = const <String>[],
  }) sync* {
    if (command.startsWith(r'$')) {
      yield RefCommand(path);
      yield* getCommands([
        ...command.substring(1).split(RegExp(r'\s+')),
        ...rest,
      ]);
    } else {
      yield ExecutableCommand(path, command, rest);
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
