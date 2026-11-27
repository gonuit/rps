import 'package:rps/rps.dart' as rps;

/// Runs commands in the configured shell.
class Executor {
  /// The shell that runs the commands.
  final rps.Shell shell;

  /// Creates an [Executor].
  Executor({required this.shell});

  /// Executes [command] in [shell], or in the configured one, and returns
  /// the exit code.
  Future<int> execute(
    String command, {
    rps.Shell? shell,
    Map<String, String>? environment,
    String? workingDirectory,
    rps.CommandOutput? output,
  }) {
    return rps.execute(
      command,
      shell: shell ?? this.shell,
      environment: environment,
      workingDirectory: workingDirectory,
      output: output,
    );
  }
}
