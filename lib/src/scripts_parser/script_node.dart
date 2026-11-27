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

  /// Environment variables of the commands under this node.
  final Map<String, String> env;

  /// Env files of the commands under this node.
  final List<String> envFiles;

  /// Creates a [ScriptNode].
  const ScriptNode({
    this.before,
    this.after,
    this.error,
    this.cwd,
    this.env = const {},
    this.envFiles = const [],
  });
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
    super.env,
    super.envFiles,
  });
}

/// A named argument declared by a script.
class ScriptArgument {
  /// Name used as `--name` on the command line and `${name}` in the command.
  final String name;

  /// Value used when the argument is not given, `null` when it is required.
  final String? defaultValue;

  /// Creates a [ScriptArgument].
  const ScriptArgument(this.name, {this.defaultValue});

  /// Whether the argument has to be given.
  bool get isRequired => defaultValue == null;
}

/// A script that can be run.
class Script extends ScriptNode {
  /// The command for the current platform.
  ///
  /// For a script with [steps] it is all of them, one per line.
  final String command;

  /// Commands run one after another, when the script is a sequence.
  final List<String>? steps;

  /// Optional human-readable description.
  final String? description;

  /// Named arguments the script accepts.
  final List<ScriptArgument> args;

  /// Creates a [Script].
  const Script({
    required this.command,
    this.steps,
    this.description,
    this.args = const [],
    super.error,
    super.before,
    super.after,
    super.cwd,
    super.env,
    super.envFiles,
  });
}
