import 'package:rps/rps.dart';

/// An execution event representing a reference to another script (via `rps`).
class CommandReferenced extends ExecutionEvent {
  @override
  final Context context;

  @override
  String get path => context.basePath.join(' ');
  @override
  final String command;

  /// Whether this reference originated from a hook.
  final bool isHook;

  /// Position among the steps of the script and their count, if any.
  final (int, int)? step;

  /// Creates a [CommandReferenced].
  CommandReferenced({
    required this.context,
    required this.command,
    this.isHook = false,
    this.step,
  });

  @override
  bool operator ==(Object other) {
    return other is CommandReferenced &&
        other.command == command &&
        other.path == path;
  }

  @override
  int get hashCode => Object.hash(path, command, runtimeType);
}
