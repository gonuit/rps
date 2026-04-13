import 'package:rps/rps.dart';

/// An execution event representing a reference to another script (via `rps`).
class CommandReferenced extends ExecutionEvent {
  @override
  final Context context;

  /// The label/key that triggered this reference.
  final String label;

  @override
  String get path => context.basePath.join(' ');
  @override
  final String command;

  /// Whether this reference originated from a hook.
  final bool isHook;

  /// Creates a [CommandReferenced].
  CommandReferenced({
    required this.context,
    required this.command,
    required this.label,
    this.isHook = false,
  });

  @override
  bool operator ==(Object other) {
    return other is CommandReferenced &&
        other.command == command &&
        other.path == path &&
        other.label == label;
  }

  @override
  int get hashCode => Object.hash(path, command, label, runtimeType);
}
