import 'dart:async';

import 'package:rps/rps.dart';
import 'package:rps/src/utils/platform.dart' show Platform;

/// Command that presents an interactive script selection menu.
class ScriptSelectionCommand {
  final FutureOr<ScriptsSource> Function() _getScriptsSource;

  /// Runs the commands of the selected script.
  final ScriptRunner runner;

  final Platform _platform;

  /// Creates a [ScriptSelectionCommand].
  ScriptSelectionCommand({
    required this.runner,
    required FutureOr<ScriptsSource> Function() getScriptsSource,
    required Platform platform,
  })  : _getScriptsSource = getScriptsSource,
        _platform = platform;

  /// Asks for a script and its arguments, then runs it.
  Future<void> run() async {
    final console = runner.console;
    final source = await _getScriptsSource();
    final parser = ScriptsParser(source: source, platform: _platform);
    final commands = parser.listCommands();

    if (commands.isEmpty) {
      throw RpsException('No scripts found.');
    }

    final selected = selectCommand(console, runner.prompt, commands);

    console.writeln('${boldGreen('>')} ${selected.path}');
    console.writeln('${boldGreen(r'$')} ${bold(selected.summary)}\n');

    if (selected.errors.isNotEmpty) {
      throw RpsConfigException(selected.errors.join('\n'));
    }
    final parameters = selected.commandArguments;
    final arguments = List.filled(parameters.length, '');
    final named = <String>[];
    for (final argument in selected.declaredArguments) {
      if (!argument.isRequired) continue;
      final value = runner.prompt.ask('Provide argument --${argument.name}:');
      named.addAll(['--${argument.name}', value]);
    }
    if (parameters.isNotEmpty) {
      for (final (index, parameter) in parameters.indexed) {
        final argument =
            runner.prompt.ask('Provide argument ${parameter.name}:');
        arguments[index] = argument;
      }
      console.writeln();
    }

    final runCommandArguments = [
      'run',
      ...selected.keys,
      ...named,
      ...arguments,
    ];

    await RunCommand(
      runner: runner,
      getScriptsSource: () => source,
      platform: _platform,
    ).run(runCommandArguments);
  }
}

/// Prompts the user to select a command from the given [commands] list.
ScriptInfo selectCommand(
  Console console,
  Prompt prompt,
  List<ScriptInfo> commands,
) {
  console.writeln('\n${bold('Which scripts do you want to run?')}');
  for (final (index, command) in commands.indexed) {
    console
      ..write('  ${green('${index + 1})')} ')
      ..write(bold(command.path))
      ..write(' ')
      ..writeln(gray('(${command.summary})'));
  }

  int? parse(String answer) {
    final index = int.tryParse(answer.trim());
    return index != null && index >= 1 && index <= commands.length
        ? index
        : null;
  }

  final answer = prompt.ask(
    'Select script:',
    validate: (answer) => parse(answer) != null,
  );
  return commands[parse(answer)! - 1];
}
