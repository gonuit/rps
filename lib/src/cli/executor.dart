import 'package:rps/src/models/interpreter.dart';
import 'package:rps/src/bindings/execute.dart' as bindings;

class Executor {
  final Interpreter? interpreter;
  final bool verbose;
  final StringSink? out;

  Executor({
    required this.interpreter,
    this.verbose = false,
    this.out,
  });

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
