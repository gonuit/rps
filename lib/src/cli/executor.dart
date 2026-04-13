import 'package:rps/src/models/interpreter.dart';
import 'package:rps/src/bindings/execute.dart' as bindings;

/// Wraps the native [execute] binding with interpreter and verbosity settings.
class Executor {
  /// Optional interpreter override for command execution.
  final Interpreter? interpreter;

  /// Whether to print verbose diagnostic output.
  final bool verbose;

  /// Optional sink for verbose output.
  final StringSink? out;

  /// Creates an [Executor].
  Executor({
    required this.interpreter,
    this.verbose = false,
    this.out,
  });

  /// Executes the given shell [command] and returns the exit code.
  Future<int> execute(
    String command,
  ) {
    return bindings.execute(
      command,
      interpreter: interpreter,
      verbose: verbose,
      out: out,
    );
  }
}
