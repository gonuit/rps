/// Shell syntax used to quote arguments appended to a script.
enum ShellSyntax {
  /// sh, bash and zsh.
  posix,

  /// Windows PowerShell.
  powershell,

  /// Windows Command Prompt.
  cmd,
}

final _posixSafe = RegExp(r'^[A-Za-z0-9_@%+=:,./-]+$');
final _powershellSafe = RegExp(r'^[A-Za-z0-9_+=:./\\-]+$');
final _cmdNeedsQuotes = RegExp('[ \t\n\v"]');
final _cmdMetaChars = RegExp(r'[ !%^&()<>|"]');

/// Quotes [argument] so the shell passes it to the command literally.
String quoteArgument(String argument, ShellSyntax syntax) {
  return switch (syntax) {
    ShellSyntax.posix => _quotePosix(argument),
    ShellSyntax.powershell => _quotePowershell(argument),
    ShellSyntax.cmd => _quoteCmd(argument),
  };
}

String _quotePosix(String argument) {
  if (argument.isEmpty) return "''";
  if (_posixSafe.hasMatch(argument)) return argument;
  return "'${argument.replaceAll("'", r"'\''")}'";
}

String _quotePowershell(String argument) {
  if (argument.isEmpty) return "''";
  if (_powershellSafe.hasMatch(argument)) return argument;
  final escaped = argument.replaceAll("'", "''").replaceAll('"', r'\"');
  return "'$escaped'";
}

String _quoteCmd(String argument) {
  if (argument.isEmpty) return '""';

  var result = argument;
  if (_cmdNeedsQuotes.hasMatch(argument)) {
    final buffer = StringBuffer('"');
    var i = 0;
    while (true) {
      var slashes = 0;
      while (i < argument.length && argument[i] == r'\') {
        i++;
        slashes++;
      }
      if (i == argument.length) {
        buffer.write(r'\' * (slashes * 2));
        break;
      }
      final escapes = argument[i] == '"' ? slashes * 2 + 1 : slashes;
      buffer
        ..write(r'\' * escapes)
        ..write(argument[i]);
      i++;
    }
    buffer.write('"');
    result = buffer.toString();
  }

  return result.replaceAllMapped(_cmdMetaChars, (m) => '^${m[0]}');
}
