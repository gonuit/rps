/// Specifies the interpreter that will be used to execute the command.
abstract interface class Interpreter {
  /// The value/name of the interpreter that corresponds
  /// to the value expected by the native library.
  String get value;
}

/// Defines possible windows interpreters
enum WindowsInterpreter implements Interpreter {
  cmd('cmd'),
  powershell('powershell');

  @override
  final String value;

  const WindowsInterpreter(this.value);
}

/// Defines possible unix interpreters
enum UnixInterpreter implements Interpreter {
  zsh('zsh'),
  sh('sh'),
  bash('bash');

  @override
  final String value;

  const UnixInterpreter(this.value);
}
