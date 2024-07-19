import 'package:collection/collection.dart';
import 'package:rps/rps.dart';
import 'dart:math' as math;

class CommandExecuted extends ExecutionEvent {
  @override
  final String command;

  @override
  final Context context;

  final List<String> arguments;

  @override
  String get path => context.path.join(' ');
  final String? description;

  final String? error;

  final bool isHook;

  static final _positionalArgumentsRegexp = RegExp(r'\$\{\s{0,}[0-9]+\s{0,}\}');

  CommandExecuted({
    required this.command,
    required this.context,
    List<String>? arguments,
    this.description,
    this.isHook = false,
    this.error,
  }) : arguments = arguments ?? const [];

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
      ].whereNotNull().join(' ');
    } else {
      return [command, _serializeArguments(arguments)].whereNotNull().join(' ');
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
