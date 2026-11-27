import 'package:rps/rps.dart' as rps;
import 'package:rps/src/models/interpreter.dart';
import 'package:rps/src/utils/platform.dart';

/// Runs shell commands with the configured interpreter.
class Executor {
  /// Optional interpreter override for command execution.
  final Interpreter? interpreter;

  /// Whether to print verbose diagnostic output.
  final bool verbose;

  /// Optional sink for verbose output.
  final StringSink? out;

  final Platform _platform;

  /// Creates an [Executor].
  Executor({
    required this.interpreter,
    required Platform platform,
    this.verbose = false,
    this.out,
  }) : _platform = platform;

  /// Executes the given shell [command] and returns the exit code.
  Future<int> execute(
    String command,
  ) {
    return rps.execute(
      command,
      interpreter: interpreter,
      verbose: verbose,
      out: out,
      platform: _platform,
    );
  }
}
