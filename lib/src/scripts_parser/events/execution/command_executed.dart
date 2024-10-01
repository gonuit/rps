import 'package:rps/rps.dart';
import 'dart:math' as math;

class PositionalArgument {
  final String name;

  /// Index of the positional argument.
  final int index;

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

  /// Whether this command is coming from hook.
  final bool isHook;

  @override
  String get path => context.path.join(' ');
  final String? description;

  final List<String> errors;
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
    required this.commandArguments,
  });

  factory CommandExecuted({
    required String command,
    required Context context,
    List<String>? arguments,
    String? description,
    bool isHook = false,
    List<String>? errors,
  }) {
    final args = arguments ?? const [];
    final errorsList = errors != null ? List<String>.of(errors) : <String>[];
    List<PositionalArgument>? scriptArguments;
    try {
      scriptArguments = getScriptArguments(command);
    } on RpsException catch (err) {
      errorsList.add(err.message);
      scriptArguments = const [];
    }

    if (scriptArguments.isNotEmpty &&
        args.length > scriptArguments.last.index) {
      final path = context.path.join(' ');
      errors?.add(
        'The script "$path" defines a positional argument '
        '${scriptArguments.last.name}, but ${args.length} '
        'positional argument(s) are given.',
      );
    }

    return CommandExecuted._internal(
      command: command,
      context: context,
      arguments: arguments ?? const [],
      errors: errorsList,
      commandArguments: scriptArguments,
      description: description,
      isHook: isHook,
    );
  }

  static List<PositionalArgument> getScriptArguments(String command) {
    final argumentsInCommand = _positionalArgumentsRegexp.allMatches(command);
    final arguments = <int>{};
    for (final match in argumentsInCommand) {
      final content = match.group(0)!;
      final value = content.substring(2, content.length - 1).trim();
      final argumentIndex = int.tryParse(value);
      if (argumentIndex == null) {
        throw RpsException(
          "Bad argument script ($content). "
          "Only positional arguments are supported.",
        );
      }
      arguments.add(argumentIndex);
    }

    // Convert to list and sort ascending.
    final argumentsList = arguments.toList()..sort();
    if (argumentsList.isNotEmpty &&
        argumentsList.length != (argumentsList.last + 1)) {
      final allArguments = List.generate(argumentsList.last, (i) => i);
      final unusedArguments =
          allArguments.where((arg) => !argumentsList.contains(arg));
      throw RpsException(
        'The script defines unused positional argument(s): '
        '${unusedArguments.map((arg) => '\${$arg}').join(', ')}',
      );
    }

    return argumentsList
        .map((arg) => PositionalArgument('\${$arg}', arg))
        .toList();
  }

  /// Escape backslashes, single and double quotes for shell safety
  /// and enclose in quotes only if necessary: contains spaces or quotes
  String? _serializeArguments(List<String> arguments) {
    if (arguments.isEmpty) return null;

    return arguments.map((arg) {
      String escaped = arg
          .replaceAll(r'\', r'\\')
          .replaceAll('"', r'\"')
          .replaceAll("'", r"\'");

      if (escaped != arg) {
        return '"$escaped"';
      }
      return escaped;
    }).join(' ');
  }

  /// Compiles the command. Returns the command ready for execution.
  String compile() {
    final errorMessage = this.errorMessage;
    if (errorMessage != null) {
      throw RpsException(errorMessage);
    }

    final argumentsInCommand = _positionalArgumentsRegexp.allMatches(command);

    if (argumentsInCommand.isNotEmpty) {
      if (isHook) {
        throw RpsException(
          'The script "$path" defines a positional argument(s), '
          'but hooks do not support positional arguments.',
        );
      }

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
          } else if (argumentIndex >= arguments.length) {
            throw RpsException(
              'The script "$path" defines a positional argument $content, '
              'but ${arguments.length} positional argument(s) are given.',
            );
          } else {
            usedArguments.add(argumentIndex);
            return arguments[argumentIndex];
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

      return [
        filledCommand,
        _serializeArguments(arguments.sublist(lastUsed + 1))
      ].nonNulls.join(' ');
    } else {
      return [command, _serializeArguments(arguments)].nonNulls.join(' ');
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
