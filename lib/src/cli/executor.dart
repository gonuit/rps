import 'package:rps/rps.dart' as rps;

/// Runs commands in the configured shell.
class Executor {
  /// The shell that runs the commands.
  final rps.Shell shell;

  /// Creates an [Executor].
  Executor({required this.shell});

  /// Executes the given shell [command] and returns the exit code.
  Future<int> execute(
    String command, {
    Map<String, String>? environment,
    String? workingDirectory,
    rps.CommandOutput? output,
  }) {
    return rps.execute(
      command,
      shell: shell,
      environment: environment,
      workingDirectory: workingDirectory,
      output: output,
    );
  }
}
