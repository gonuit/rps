/// A node of the scripts tree.
sealed class ScriptNode {
  /// Command of the `$before` hook, if any.
  final String? before;

  /// Command of the `$after` hook, if any.
  final String? after;

  /// Creates a [ScriptNode].
  const ScriptNode({this.before, this.after});
}

/// A group of scripts.
class ScriptGroup extends ScriptNode {
  /// Scripts and groups of this group by their key.
  final Map<String, ScriptNode> children;

  /// Creates a [ScriptGroup].
  const ScriptGroup({required this.children, super.before, super.after});
}

/// A script that can be run.
class Script extends ScriptNode {
  /// The command for the current platform.
  final String command;

  /// Optional human-readable description.
  final String? description;

  /// The reason this script cannot be run, if any.
  final String? error;

  /// Creates a [Script].
  const Script({
    required this.command,
    this.description,
    this.error,
    super.before,
    super.after,
  });
}
