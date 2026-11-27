/// A node of the scripts tree.
sealed class ScriptNode {
  /// Command of the `$before` hook, if any.
  final String? before;

  /// Command of the `$after` hook, if any.
  final String? after;

  /// The reason nothing under this node can be run, if any.
  final String? error;

  /// Working directory of the commands under this node, if set.
  final String? cwd;

  /// Creates a [ScriptNode].
  const ScriptNode({this.before, this.after, this.error, this.cwd});
}

/// A group of scripts.
class ScriptGroup extends ScriptNode {
  /// Scripts and groups of this group by their key.
  final Map<String, ScriptNode> children;

  /// Creates a [ScriptGroup].
  const ScriptGroup({
    required this.children,
    super.before,
    super.after,
    super.error,
    super.cwd,
  });
}

/// A script that can be run.
class Script extends ScriptNode {
  /// The command for the current platform.
  final String command;

  /// Optional human-readable description.
  final String? description;

  /// Creates a [Script].
  const Script({
    required this.command,
    this.description,
    super.error,
    super.before,
    super.after,
    super.cwd,
  });
}
