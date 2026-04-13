/// Specifies the interpreter that will be used to execute the command.
abstract interface class Interpreter {
  /// The value/name of the interpreter that corresponds
  /// to the value expected by the native library.
  String get value;
}

/// Defines possible windows interpreters
enum WindowsInterpreter implements Interpreter {
  /// Windows Command Prompt.
  cmd('cmd'),

  /// Windows PowerShell.
  powershell('powershell');

  @override
  final String value;

  const WindowsInterpreter(this.value);
}

/// Defines possible unix interpreters
enum UnixInterpreter implements Interpreter {
  /// Z shell.
  zsh('zsh'),

  /// Bourne shell.
  sh('sh'),

  /// Bash shell.
  bash('bash');

  @override
  final String value;

  const UnixInterpreter(this.value);
}
