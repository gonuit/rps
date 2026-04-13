import 'package:rps/src/models/interpreter.dart';
import 'package:rps/src/bindings/execute.dart' as bindings;
import 'package:rps/src/utils/file_system.dart';
import 'package:rps/src/utils/platform.dart';

/// Wraps the native [execute] binding with interpreter and verbosity settings.
class Executor {
  /// Optional interpreter override for command execution.
  final Interpreter? interpreter;

  /// Whether to print verbose diagnostic output.
  final bool verbose;

  /// Optional sink for verbose output.
  final StringSink? out;

  final Platform _platform;
  final FileSystem _fs;

  /// Creates an [Executor].
  Executor({
    required this.interpreter,
    required Platform platform,
    required FileSystem fs,
    this.verbose = false,
    this.out,
  })  : _platform = platform,
        _fs = fs;

  /// Executes the given shell [command] and returns the exit code.
  Future<int> execute(
    String command,
  ) {
    return bindings.execute(
      command,
      interpreter: interpreter,
      verbose: verbose,
      out: out,
      platform: _platform,
      fs: _fs,
    );
  }
}
