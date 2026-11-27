/// Specifies the interpreter that will be used to execute the command.
abstract interface class Interpreter {
  /// The name of the interpreter executable.
  String get value;
}

/// Defines possible windows interpreters
enum WindowsInterpreter implements Interpreter {
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
