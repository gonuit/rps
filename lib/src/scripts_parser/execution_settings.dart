import 'package:rps/rps.dart';

/// Where and how the commands of a script run.
class ExecutionSettings {
  /// Directory that relative paths start from, the current one when null.
  final String? baseDirectory;

  /// Directory the commands run in, relative to [baseDirectory], if set.
  final String? cwd;

  /// Environment variables set for the commands.
  final Map<String, String> env;

  /// Env files loaded for the commands, later files win.
  final List<String> envFiles;

  /// The shell that runs the commands, the default one when null.
  final Shell? shell;

  /// Creates an [ExecutionSettings].
  const ExecutionSettings({
    this.baseDirectory,
    this.cwd,
    this.env = const {},
    this.envFiles = const [],
    this.shell,
  });

  /// Returns the settings with those of [node] applied on top.
  ExecutionSettings enter(ScriptNode node) {
    return ExecutionSettings(
      baseDirectory: baseDirectory,
      cwd: node.cwd ?? cwd,
      env: {...env, ...node.env},
      envFiles: [...envFiles, ...node.envFiles],
      shell: shell,
    );
  }
}
