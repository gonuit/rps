import 'dart:io';

import 'package:rps/commands/run_command.dart';
import 'package:rps/pubspec.dart';
import 'package:rps/rps.dart' as rps;
import 'package:rps/rps_exception.dart';
import 'package:rps/utils.dart';

void main(List<String> args) async {
  try {
    if (args.length == 1 && args.first.trim() == '--version') {
      final ver = await rps.getPackageVersion();
      stdout.writeln('rps version: ${rps.applyBold(ver)}');
      exit(0);
    } else if (args.length == 1 && args.first.trim() == '--help') {
      final ver = await rps.getPackageVersion();
      stdout.writeln(
        '${applyBold('Run Pubspec Script')} (${applyBoldGreen('rps')}) ${rps.applyBold("v$ver")}\n\n'
        '${applyBold('Options')}:\n'
        '  --version - prints version.\n'
        '  --help    - prints help.\n'
        '${applyBold('Commands')}:\n'
        '  run <pubspec command> <command options> - runs a script from pubspec.yaml file.\n',
      );
      await stdout.flush();
      exit(0);
    } else {
      final pubspec = await Pubspec.load(Directory.current);
      final runCommand = RunCommand(pubspec);

      if (args.isEmpty) {
        final exitCode = await runCommand.run(['run']);
        exit(exitCode);
      } else if (args.first.trim() == 'run') {
        final exitCode = await runCommand.run(args.sublist(1));
        exit(exitCode);
      } else {
        final exitCode = await runCommand.run(args);
        exit(exitCode);
      }
    }
  } on RpsException catch (err) {
    stderr.writeln("${rps.applyBoldRed('Error!')} ${err.message}");
    await stderr.flush();
    exit(1);
  } catch (err, st) {
    stderr.writeln("${rps.applyBoldRed('Error!')} $err\n$st");
    await stderr.flush();
    exit(1);
  }
}
