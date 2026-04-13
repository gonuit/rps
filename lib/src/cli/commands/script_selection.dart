import 'dart:async';

import 'package:prompts/prompts.dart' as prompts;
import 'package:rps/rps.dart';
import 'package:rps/src/cli/commands/command.dart';
import 'package:rps/src/cli/executor.dart';
import 'package:rps/src/utils/platform.dart' show Platform;

/// Command that presents an interactive script selection menu.
class ScriptSelectionCommand implements Command {
  final FutureOr<ScriptsSource> Function() _getScriptsSource;

  /// The executor used to run shell commands.
  final Executor executor;

  final Platform _platform;

  /// Creates a [ScriptSelectionCommand].
  ScriptSelectionCommand({
    required this.executor,
    required FutureOr<ScriptsSource> Function() getScriptsSource,
    required Platform platform,
  })  : _getScriptsSource = getScriptsSource,
        _platform = platform;

  @override
  String get description =>
      'Call without arguments to select a command to run.';

  @override
  Null get name => null;

  @override
  Null get tooltip => null;

  @override
  bool match(List<String> arguments) {
    return arguments.isEmpty;
  }

  @override
  Future<void> run(Console console, List<String> arguments) async {
    final source = await _getScriptsSource();
    final parser = ScriptsParser(source: source, platform: _platform);
    final commands = parser.listCommands().where((c) => !c.isHook).toList();

    final selected = selectCommand(console, commands);
    if (selected == null) {
      throw RpsException('Script not selected.');
    }

    console.writeln('${boldGreen('>')} ${selected.path}');
    console.writeln('${boldGreen(r'$')} ${bold(selected.command)}\n');

    if (selected.errors.isNotEmpty) {
      throw RpsException(selected.errors.join('\n'));
    }
    final parameters = selected.commandArguments;
    final arguments = List.filled(parameters.length, '');
    if (parameters.isNotEmpty) {
      for (final (index, parameter) in parameters.indexed) {
        final argument = prompts.get(
          'Provide argument ${parameter.name}:',
          chevron: false,
          validate: (arg) => true,
        );
        arguments[index] = argument;
      }
      console.writeln();
    }

    final runCommandArguments = selected.context.path + arguments;

    await RunCommand(
      executor: executor,
      getScriptsSource: () => source,
      platform: _platform,
    ).run(console, runCommandArguments);
  }
}

/// Prompts the user to select a command from the given [commands] list.
CommandExecuted? selectCommand(
  Console console,
  List<CommandExecuted> commands,
) {
  console.writeln('\n${bold('Which scripts do you want to run?')}');
  for (int i = 0; i < commands.length; i++) {
    final command = commands[i];
    console
      ..write('  ${i + 1}) ')
      ..write(lightBlue(command.path))
      ..write(' ')
      ..writeln('(${gray(command.command)})');
  }

  final line = prompts.get(
    'Select script:',
    chevron: false,
    validate: (s) {
      if (s.isEmpty) return false;
      var index = int.tryParse(s);
      if (index == null) return false;
      return index >= 1 && index <= commands.length;
    },
  );

  final int? index = int.tryParse(line);

  if (index == null || index > commands.length || index < 1) return null;

  return commands[index - 1];
}
