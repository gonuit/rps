import 'dart:io';

import 'package:rps/src/bindings/execute.dart' as bindings;
import 'package:rps/rps.dart';
import 'package:rps/src/commands/command.dart';

class RunCommand implements Command {
  final Pubspec pubspec;

  RunCommand(this.pubspec);

  @override
  String get description =>
      'This runs an arbitrary command from a pubspec\'s "scripts" object. '
      'If no "command" is provided, it will list the available scripts.';

  @override
  String get name => 'run';

  Future<int> run(List<String> args) async {
    final arguments = args;

    /// Cycle detection is based on duplicates, this can be improved
    final commands = <PubspecCommand>{};

    int commandsCount = 0;
    for (final command in pubspec.getCommands(arguments)) {
      commands.add(command);
      if (commands.length < ++commandsCount) {
        throw RpsException(
          'Script cycle detected: ${[
            ...commands.map((e) => e.path),
            command.path
          ].join(' → ')}',
        );
      }
    }

    if (commands.isEmpty) {
      throw RpsException(
        'Missing script. Command: "${arguments.join(' ')}" '
        'is not a full path.',
      );
    }

    for (final command in commands.whereType<ExecutableCommand>()) {
      stdout.writeln('${applyBoldGreen('>')} ${command.path}');
      stdout.writeln(
        '${applyBoldGreen(r'$')} ${applyBold(command.command)}\n',
      );
      final exitCode = await bindings.execute(command.command);

      if (exitCode > 0) {
        throw RpsException('Command ended with a non zero exit code.');
      }
      stdout.writeln();
    }

    return 0;
  }
}
