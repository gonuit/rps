import 'dart:async';

import 'package:rps/rps.dart';
import 'package:rps/src/bindings/execute.dart' as bindings;
import 'package:rps/src/cli/commands/command.dart';

class RunCommand implements Command {
  final FutureOr<ScriptsSource> Function() _getScriptsSource;

  RunCommand({
    required FutureOr<ScriptsSource> Function() getScriptsSource,
  }) : _getScriptsSource = getScriptsSource;

  @override
  String get description => 'This runs an arbitrary command from a pubspec\'s "scripts" object. '
      'If no "command" is provided, it will list the available scripts.';

  @override
  String get name => 'run';

  @override
  String? get tooltip => 'run <pubspec script> [arguments]';

  @override
  bool match(List<String> arguments) {
    return true;
  }

  @override
  Future<int> run(Console console, List<String> arguments) async {
    final source = await _getScriptsSource();
    final parser = ScriptsParser(source: source);

    final List<ExecutionEvent> events;
    try {
      events = parser.getCommandsToExecute(arguments);
    } on ScriptParserException catch (err) {
      throw RpsException(err.message, err);
    }

    if (events.isEmpty) {
      throw RpsException(
        'Missing script. Command: "${arguments.join(' ')}" '
        'is not a full path.',
      );
    }

    for (final event in events) {
      if (event is CommandExecuted) {
        console.writeln('${boldGreen('>')} ${event.context.basePath.join(' ')}');
        console.writeln('${boldGreen(r'$')} ${bold(event.command)}\n');
        final exitCode = await bindings.execute(event.command);

        if (exitCode > 0) {
          throw RpsException('Command ended with a non zero exit code.');
        }
        console.writeln();
      } else if (event is CommandReferenced) {
        console.writeln('${boldGreen(r'$ rps')} ${bold(event.command)}\n');
      } else if (event is HookExecuted) {
        final basePath = event.context.basePath;
        console.writeln('${boldGreen('>')} ${basePath.sublist(0, basePath.length - 1).join(' ')} ${blue(event.name)}');
      }
    }

    return 0;
  }
}
