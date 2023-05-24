import 'dart:io';

import 'package:rps/commands/run_command.dart';
import 'package:rps/pubspec.dart';
import 'package:rps/rps.dart' as rps;
import 'package:rps/rps_exception.dart';
import 'package:rps/utils.dart';
import 'package:rps/bindings/execute.dart' as bindings;

void main(List<String> args) async {
  try {
    if (args.length == 1 && args.first.trim() == '--version' ||
        args.first.trim() == '-v') {
      final ver = await rps.getPackageVersion();
      stdout
        ..writeln()
        ..writeln('📝 rps version: ${rps.applyBold(ver)}')
        ..writeln();
      exit(0);
    } else if (args.length == 1 && args.first.trim() == '--help' ||
        args.first.trim() == '-h') {
      final ver = await rps.getPackageVersion();
      stdout.writeln(
        '${applyBold('Run Pubspec Script')} (${applyBoldGreen('rps')}) ${rps.applyBold("v$ver")}\n\n'
        '${applyBold('Options')}:\n'
        '  -v, --version - prints version.\n'
        '  -h, --help    - prints help.\n'
        '  -u, --upgrade - upgrades rps package.\n'
        '${applyBold('Commands')}:\n'
        '  run <pubspec script> [arguments] - runs a script from pubspec.yaml file.\n',
      );
      await stdout.flush();
      exit(0);
    } else if (args.length == 1 && args.first.trim() == '--upgrade' ||
        args.first.trim() == '-u') {
      const command = 'dart pub global activate rps';
      stdout.write(
        '${applyBoldBlue('\n⏳ Upgrading rps package...')}\n\n'
        '${applyBoldGreen(r'$')} ${applyBold(command)}\n\n',
      );

      final exitCode = await bindings.execute(command);
      if (exitCode > 0) {
        throw RpsException(
          'Failed to update the rps package. '
          'Command ended with a non zero exit code.',
        );
      } else {
        stdout
          ..writeln()
          ..writeln(applyBoldGreen('✓ rps updated successfully!'))
          ..writeln();
        await stdout.flush();
      }
      exit(exitCode);
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
