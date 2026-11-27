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
                  {
                    'name': argument.name,
                    'index': argument.index,
                    'option': null,
                    'required': true,
                    'default': null,
                  },
                for (final argument in command.declaredArguments)
                  {
                    'name': argument.name,
                    'index': null,
                    'option': '--${argument.name}',
                    'required': argument.isRequired,
                    'default': argument.defaultValue,
                  },
              ],
              'steps': command.steps,
              'parallel': command.parallel,
              'cwd': command.workingDirectory,
              'env': command.environment.keys.toList(),
              'envFiles': command.envFiles,
              'confirm': command.confirmation,
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
          ..writeln('(${gray(command.summary)})');
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
        final details = [
          if (command.declaredArguments.isNotEmpty)
            'Arguments: ${[
              for (final argument in command.declaredArguments)
                argument.isRequired
                    ? '--${argument.name}'
                    : '[--${argument.name}=${argument.defaultValue}]',
            ].join(' ')}',
          if (command.workingDirectory != null)
            'Runs in: ${command.workingDirectory}',
          if (command.confirmation != null) 'Asks for confirmation.',
        ];
        for (final detail in details) {
          console
            ..write('    ')
            ..writeln(gray(detail));
        }
      }
    }
  }
}
