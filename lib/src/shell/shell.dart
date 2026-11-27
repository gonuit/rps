import 'package:rps/rps.dart';
import 'package:rps/src/models/interpreter.dart';
import 'package:rps/src/utils/platform.dart';

/// A command interpreter that runs scripts.
sealed class Shell {
  /// Creates a [Shell].
  const Shell();

  /// Returns the shell for [interpreter], or the default one of [platform].
  factory Shell.of(Interpreter? interpreter, Platform platform) {
    if (!platform.isWindows && interpreter is WindowsInterpreter) {
      throw RpsException(
        'The Windows interpreter cannot be used '
        'on ${platform.operatingSystem}.',
      );
    }
    if (!platform.isLinux &&
        !platform.isMacOS &&
        interpreter is UnixInterpreter) {
      throw RpsException(
        'The Unix interpreter cannot be used on ${platform.operatingSystem}.',
      );
    }
    return switch (interpreter) {
      null => platform.isWindows ? const PowerShell() : const PosixShell(),
      WindowsInterpreter.powershell => const PowerShell(),
      WindowsInterpreter.cmd => const CmdShell(),
      _ => PosixShell(interpreter.value),
    };
  }

  /// The program that is started.
  String get executable;

  /// Arguments of [executable] that make it run [command].
  List<String> arguments(String command);

  /// Quotes [argument] so the shell passes it to the command literally.
  String quote(String argument);
}

/// sh, bash and zsh.
class PosixShell extends Shell {
  static final _safe = RegExp(r'^[A-Za-z0-9_@%+=:,./-]+$');

  @override
  final String executable;

  /// Creates a [PosixShell] that starts [executable].
  const PosixShell([this.executable = 'bash']);

  @override
  List<String> arguments(String command) => ['-c', command];

  @override
  String quote(String argument) {
    if (argument.isEmpty) return "''";
    if (_safe.hasMatch(argument)) return argument;
    return "'${argument.replaceAll("'", r"'\''")}'";
  }
}

/// Windows PowerShell.
class PowerShell extends Shell {
  static final _safe = RegExp(r'^[A-Za-z0-9_+=:./\\-]+$');

  /// Creates a [PowerShell].
  const PowerShell();

  @override
  String get executable => 'powershell';

  @override
  List<String> arguments(String command) => ['-Command', command];

  @override
  String quote(String argument) {
    if (argument.isEmpty) return "''";
    if (_safe.hasMatch(argument)) return argument;
    final escaped = argument.replaceAll("'", "''").replaceAll('"', r'\"');
    return "'$escaped'";
  }
}

/// Windows Command Prompt.
class CmdShell extends Shell {
  static final _needsQuotes = RegExp('[ \t\n\v"]');
  static final _metaChars = RegExp(r'[ !%^&()<>|"]');

  /// Creates a [CmdShell].
  const CmdShell();

  @override
  String get executable => 'cmd';

  @override
  List<String> arguments(String command) => ['/c', command];

  @override
  String quote(String argument) {
    if (argument.isEmpty) return '""';

    var result = argument;
    if (_needsQuotes.hasMatch(argument)) {
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

    return result.replaceAllMapped(_metaChars, (m) => '^${m[0]}');
  }
}
