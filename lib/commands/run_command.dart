import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:rps/bindings/execute.dart' as bindings;
import 'package:rps/rps.dart';

class RunCommand extends Command<int> {
  final Pubspec pubspec;

  RunCommand(this.pubspec);
  @override
  String get description => 'Run script from pubspec.yaml.';

  @override
  String get name => 'run';

  @override
  Future<int> run() async {
    final arguments = argResults?.arguments;
    if (arguments == null) {
      throw RpsException('Missing $name command arguments.');
    }

    var beforeExitCode = 0;
    final beforeCmd = pubspec.getCommand(arguments, before: true);
    if (beforeCmd.command != null) {
      stdout.writeln(
        '\n${applyBoldGreen('>')} ${beforeCmd.path}',
      );
      stdout.writeln(
        '${applyBoldGreen(r'$')} '
        '${applyBold(beforeCmd.command!)}\n',
      );
      beforeExitCode = await bindings.execute(beforeCmd.command!);
    }
    if (beforeExitCode > 0) {
      throw RpsException('"before-" hook failed.');
    }

    final cmd = pubspec.getCommand(arguments);
    stdout.writeln(
      '\n${applyBoldGreen('>')} ${cmd.path}',
    );
    stdout.writeln(
      '${applyBoldGreen(r'$')} '
      '${applyBold(cmd.command!)}\n',
    );
    final exitCode = await bindings.execute(cmd.command!);

    if (exitCode > 0) {
      throw RpsException('Command ended with a non zero exit code.');
    }

    var afterExitCode = 0;
    final afterCmd = pubspec.getCommand(arguments, after: true);
    if (afterCmd.command != null) {
      stdout.writeln(
        '\n${applyBoldGreen('>')} ${afterCmd.path}',
      );
      stdout.writeln(
        '${applyBoldGreen(r'$')} '
        '${applyBold(afterCmd.command!)}\n',
      );
      afterExitCode = await bindings.execute(afterCmd.command!);
    }
    if (afterExitCode > 0) {
      throw RpsException('"after-" hook failed.');
    }

    return exitCode;
  }
}
