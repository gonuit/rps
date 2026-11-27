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

  static final _placeholder = RegExp(r'\$\{\s*([0-9]+)\s*\}');

  /// Extracts positional argument placeholders from [command],
  /// sorted by index.
  ///
  /// Unless [contiguous] is disabled, the indexes must start
  /// at 0 and have no gaps.
  static List<PositionalArgument> parse(
    String command, {
    bool contiguous = true,
  }) {
    final indexes = {
      for (final match in _placeholder.allMatches(command))
        int.parse(match[1]!),
    }.toList()
      ..sort();
    if (contiguous &&
        indexes.isNotEmpty &&
        indexes.length != indexes.last + 1) {
      final unused = [
        for (var index = 0; index < indexes.last; index++)
          if (!indexes.contains(index)) '\${$index}',
      ];
      throw RpsConfigException(
        'The script defines unused positional argument(s): '
        '${unused.join(', ')}',
      );
    }
    return [
      for (final index in indexes) PositionalArgument('\${$index}', index)
    ];
  }

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

  /// Values of the named arguments, by name.
  final Map<String, String> named;

  /// Positional arguments used by the command, sorted by index.
  ///
  /// Empty when the command could not be parsed; [errors] has the reason.
  final List<PositionalArgument> commandArguments;

  /// Whether this command is coming from hook.
  final bool isHook;

  /// Position among the steps of the script and their count, if any.
  ///
  /// A step uses the arguments it refers to and ignores the rest.
  final (int, int)? step;

  @override
  String get path => context.path.join(' ');

  /// Errors encountered while parsing this command.
  final List<String> errors;

  /// Directory the command runs in, relative to the project, if set.
  final String? workingDirectory;

  /// Environment variables set for the command.
  final Map<String, String> environment;

  /// Env files loaded for the command, later files win.
  final List<String> envFiles;

  /// Returns a combined error message, or null if there are no errors.
  String? get errorMessage => errors.isEmpty ? null : errors.join('\n');

  CommandExecuted._internal({
    required this.command,
    required this.context,
    required this.arguments,
    required this.errors,
    required this.isHook,
    required this.step,
    required this.named,
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
    Map<String, String> named = const {},
    bool isHook = false,
    (int, int)? step,
    String? workingDirectory,
    Map<String, String> environment = const {},
    List<String> envFiles = const [],
  }) {
    final errors = <String>[];
    var commandArguments = const <PositionalArgument>[];
    try {
      commandArguments = PositionalArgument.parse(
        command,
        contiguous: step == null,
      );
    } on RpsException catch (err) {
      errors.add(err.message);
    }

    return CommandExecuted._internal(
      command: command,
      context: context,
      arguments: arguments ?? const [],
      errors: errors,
      commandArguments: commandArguments,
      isHook: isHook,
      step: step,
      named: named,
      workingDirectory: workingDirectory,
      environment: environment,
      envFiles: envFiles,
    );
  }

  String _fill(Shell shell) {
    final names = named.keys.map(RegExp.escape).join('|');
    final pattern = RegExp(
      named.isEmpty
          ? r'\$\{\s*([0-9]+)\s*\}'
          : '\\\$\\{\\s*(?:([0-9]+)|($names))\\s*\\}',
    );
    return command.replaceAllMapped(pattern, (match) {
      final digits = match[1];
      if (digits == null) return shell.quote(named[match[2]!]!);
      final index = int.parse(digits);
      if (index >= arguments.length) {
        throw RpsUsageException(
          'The script "$path" defines a positional argument ${match[0]}, '
          'but ${arguments.length} positional argument(s) are given.',
        );
      }
      return arguments[index];
    });
  }

  /// Compiles the command. Returns the command ready for execution.
  String compile({Shell shell = const PosixShell()}) {
    final errorMessage = this.errorMessage;
    if (errorMessage != null) {
      throw RpsConfigException(errorMessage);
    }
    if (isHook && commandArguments.isNotEmpty) {
      throw RpsConfigException(
        'The script "$path" defines a positional argument(s), '
        'but hooks do not support positional arguments.',
      );
    }

    final filled = _fill(shell);
    final trailing = arguments.skip(commandArguments.length);
    if (step != null || trailing.isEmpty) return filled;
    return '$filled ${trailing.map(shell.quote).join(' ')}';
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
