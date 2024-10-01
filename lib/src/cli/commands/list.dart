import 'dart:async';

import 'package:rps/rps.dart';
import 'package:rps/src/cli/commands/command.dart';

class LsCommand implements Command {
  final FutureOr<ScriptsSource> Function() _getScriptsSource;

  LsCommand({
    required FutureOr<ScriptsSource> Function() getScriptsSource,
  }) : _getScriptsSource = getScriptsSource;

  @override
  String get description => 'List all commands.';

  @override
  String get name => 'ls';

  @override
  String get tooltip => 'ls';

  @override
  bool match(List<String> arguments) {
    return arguments.isNotEmpty && arguments[0] == 'ls';
  }

  @override
  Future<void> run(Console console, List<String> arguments) async {
    final source = await _getScriptsSource();
    final parser = ScriptsParser(source: source);
    final commands = parser.listCommands().toList();
    if (commands.isNotEmpty) {
      console.writeln('${bold('Commands')}:');
      for (final command in commands) {
        console
          ..write('  ')
          ..write(lightBlue(command.path))
          ..write(' ')
          ..writeln('(${gray(command.command)})');
        final errorMessage = command.errorMessage;
        if (errorMessage != null) {
          console
            ..write('    ')
            ..writeln(red(errorMessage));
        }
        if (command.description != null) {
          console
            ..write('    ')
            ..writeln(command.description);
        }
      }
    }
  }
}
