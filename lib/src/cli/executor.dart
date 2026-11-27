import 'package:rps/rps.dart' as rps;

/// Runs commands in the configured shell.
class Executor {
  /// The shell that runs the commands.
  final rps.Shell shell;

  /// Whether to print verbose diagnostic output.
  final bool verbose;

  /// Optional sink for verbose output.
  final StringSink? out;

  /// Creates an [Executor].
  Executor({
    required this.shell,
    this.verbose = false,
    this.out,
  });

  /// Executes the given shell [command] and returns the exit code.
  Future<int> execute(
    String command, {
    Map<String, String>? environment,
    String? workingDirectory,
  }) {
    return rps.execute(
      command,
      shell: shell,
      environment: environment,
      workingDirectory: workingDirectory,
      verbose: verbose,
      out: out,
    );
  }
}
