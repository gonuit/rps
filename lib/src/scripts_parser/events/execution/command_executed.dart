import 'dart:math' as math;

import 'package:rps/rps.dart';

/// A positional argument placeholder parsed from a command string.
class PositionalArgument {
  /// The placeholder name (e.g. `${0}`).
  final String name;

  /// Index of the positional argument.
  final int index;

  /// Creates a [PositionalArgument].
  PositionalArgument(
    this.name,
    this.index,
  );

  @override
  int get hashCode => Object.hash(name, index);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PositionalArgument &&
        name == other.name &&
        index == other.index;
  }
}

/// An execution event representing a concrete command to run.
class CommandExecuted extends ExecutionEvent {
  @override
  final String command;

  @override
  final Context context;

  /// Arguments that were provided to this command.
  final List<String> arguments;

  /// Arguments parsed from command.
  ///
  /// When null, parsing of the command has failed and [errors] list
  /// should contain the reason.
  ///
  /// The list is always sorted in ascending order based
  /// on the positional argument index.
  final List<PositionalArgument> commandArguments;

  /// Values of the named arguments, by name.
  final Map<String, String> named;

  /// Named arguments declared by the script.
  final List<ScriptArgument> declaredArguments;

  /// Whether this command is coming from hook.
  final bool isHook;

  /// Position among the steps of the script and their count, if any.
  ///
  /// A step uses the arguments it refers to and ignores the rest.
  final (int, int)? step;

  @override
  String get path => context.path.join(' ');

  /// Optional human-readable description of this command.
  final String? description;

  /// Errors encountered while parsing this command.
  final List<String> errors;

  /// Directory the command runs in, relative to the project, if set.
  final String? workingDirectory;

  /// Environment variables set for the command.
  final Map<String, String> environment;

  /// Env files loaded for the command, later files win.
  final List<String> envFiles;

  /// Returns a combined error message, or null if there are no errors.
  String? get errorMessage {
    final message = errors.whereType<String>().join('\n');
    return message.isEmpty ? null : message;
  }

  static final _positionalArgumentsRegexp = RegExp(r'\$\{\s{0,}[0-9]+\s{0,}\}');

  CommandExecuted._internal({
    required this.command,
    required this.context,
    required this.arguments,
    required this.errors,
    required this.description,
    required this.isHook,
    required this.step,
    required this.named,
    required this.declaredArguments,
    required this.commandArguments,
    required this.workingDirectory,
    required this.environment,
    required this.envFiles,
  });

  /// Creates a [CommandExecuted], parsing positional arguments from [command].
  factory CommandExecuted({
    required String command,
    required Context context,
    List<String>? arguments,
    String? description,
    Map<String, String> named = const {},
    List<ScriptArgument> declaredArguments = const [],
    bool isHook = false,
    (int, int)? step,
    List<String>? errors,
    String? workingDirectory,
    Map<String, String> environment = const {},
    List<String> envFiles = const [],
  }) {
    final errorsList = errors != null ? List<String>.of(errors) : <String>[];
    List<PositionalArgument>? scriptArguments;
    try {
      scriptArguments = getScriptArguments(command, contiguous: step == null);
    } on RpsException catch (err) {
      errorsList.add(err.message);
      scriptArguments = const [];
    }

    return CommandExecuted._internal(
      command: command,
      context: context,
      arguments: arguments ?? const [],
      errors: errorsList,
      commandArguments: scriptArguments,
      description: description,
      isHook: isHook,
      step: step,
      named: named,
      declaredArguments: declaredArguments,
      workingDirectory: workingDirectory,
      environment: environment,
      envFiles: envFiles,
    );
  }

  /// Extracts positional argument placeholders from [command].
  ///
  /// Unless [contiguous] is disabled, the indexes must start
  /// at 0 and have no gaps.
  static List<PositionalArgument> getScriptArguments(
    String command, {
    bool contiguous = true,
  }) {
    final argumentsInCommand = _positionalArgumentsRegexp.allMatches(command);
    final arguments = <int>{};
    for (final match in argumentsInCommand) {
      final content = match.group(0)!;
      final value = content.substring(2, content.length - 1).trim();
      final argumentIndex = int.tryParse(value);
      if (argumentIndex == null) {
        throw RpsConfigException(
          'Bad argument script ($content). '
          'Only positional arguments are supported.',
        );
      }
      arguments.add(argumentIndex);
    }

    // Convert to list and sort ascending.
    final argumentsList = arguments.toList()..sort();
    if (contiguous &&
        argumentsList.isNotEmpty &&
        argumentsList.length != (argumentsList.last + 1)) {
      final allArguments = List.generate(argumentsList.last, (i) => i);
      final unusedArguments =
          allArguments.where((arg) => !argumentsList.contains(arg));
      throw RpsConfigException(
        'The script defines unused positional argument(s): '
        '${unusedArguments.map((arg) => '\${$arg}').join(', ')}',
      );
    }

    return argumentsList
        .map((arg) => PositionalArgument('\${$arg}', arg))
        .toList();
  }

  String? _serializeArguments(List<String> arguments, Shell shell) {
    if (arguments.isEmpty) return null;
    return arguments.map(shell.quote).join(' ');
  }

  String _fill(Shell shell, [String Function(Match match)? positional]) {
    final names = named.keys.map(RegExp.escape).join('|');
    final pattern = named.isEmpty
        ? _positionalArgumentsRegexp
        : RegExp('\\\$\\{\\s*(?:[0-9]+|($names))\\s*\\}');
    return command.replaceAllMapped(pattern, (match) {
      final name = named.isEmpty ? null : match[1];
      if (name != null) return shell.quote(named[name]!);
      return positional == null ? match[0]! : positional(match);
    });
  }

  /// Compiles the command. Returns the command ready for execution.
  String compile({Shell shell = const PosixShell()}) {
    final errorMessage = this.errorMessage;
    if (errorMessage != null) {
      throw RpsConfigException(errorMessage);
    }

    final argumentsInCommand = _positionalArgumentsRegexp.allMatches(command);

    if (argumentsInCommand.isNotEmpty) {
      if (isHook) {
        throw RpsConfigException(
          'The script "$path" defines a positional argument(s), '
          'but hooks do not support positional arguments.',
        );
      }

      final usedArguments = <int>{};
      final filledCommand = _fill(
        shell,
        (match) {
          final content = match.group(0)!;
          final value = content.substring(2, content.length - 1).trim();
          final argumentIndex = int.tryParse(value);
          if (argumentIndex == null) {
            throw RpsConfigException(
              'Bad argument script ($content). '
              'Only positional arguments are supported.',
            );
          } else if (argumentIndex >= arguments.length) {
            throw RpsUsageException(
              'The script "$path" defines a positional argument $content, '
              'but ${arguments.length} positional argument(s) are given.',
            );
          } else {
            usedArguments.add(argumentIndex);
            return arguments[argumentIndex];
          }
        },
      );

      if (step != null) return filledCommand;

      final lastUsed = usedArguments.reduce(math.max);
      if (lastUsed >= usedArguments.length) {
        final unusedArguments = List<int>.generate(lastUsed, (index) => index)
            .where((e) => !usedArguments.contains(e));

        throw RpsConfigException(
          'The script defines unused positional argument(s): '
          '${unusedArguments.map((a) => '\${$a}').join(', ')}',
        );
      }

      return [
        filledCommand,
        _serializeArguments(arguments.sublist(lastUsed + 1), shell)
      ].nonNulls.join(' ');
    } else if (step != null) {
      return _fill(shell);
    } else {
      return [_fill(shell), _serializeArguments(arguments, shell)]
          .nonNulls
          .join(' ');
    }
  }

  @override
  bool operator ==(Object other) {
    return other is CommandExecuted &&
        other.command == command &&
        other.path == path;
  }

  @override
  int get hashCode => Object.hash(path, command, runtimeType);
}
