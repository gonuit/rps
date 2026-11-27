import 'dart:async';
import 'dart:convert';

import 'package:rps/rps.dart';
import 'package:rps/src/utils/platform.dart' show Platform;

/// The `ls` command that lists all available scripts.
class LsCommand {
  final FutureOr<ScriptsSource> Function() _getScriptsSource;
  final Platform _platform;

  /// Creates an [LsCommand].
  LsCommand({
    required FutureOr<ScriptsSource> Function() getScriptsSource,
    required Platform platform,
  })  : _getScriptsSource = getScriptsSource,
        _platform = platform;

  /// Prints the scripts to [console], as JSON when [json] is set.
  Future<void> run(Console console, {bool json = false}) async {
    final source = await _getScriptsSource();
    final parser = ScriptsParser(source: source, platform: _platform);
    final commands = parser.listCommands().where((c) => !c.isHook).toList();
    if (json) {
      console.writeln(const JsonEncoder.withIndent('  ').convert({
        'scripts': [
          for (final command in commands)
            {
              'path': command.path,
              'command': command.command,
              'description': command.description,
              'arguments': [
                for (final argument in command.commandArguments)
                  {'name': argument.name, 'index': argument.index},
              ],
              'errors': command.errors,
            },
        ],
      }));
      return;
    }
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
