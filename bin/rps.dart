import 'dart:io';

import 'package:rps/src/utils/rps_package.dart';
import 'package:rps/rps.dart';
import 'package:rps/src/bindings/execute.dart' as bindings;

void main(List<String> args) async {
  try {
    final package = await RpsPackage.load();
    if (true) {
      try {
        final versions = await package.getVersions();
        if (versions.hasUpdate) {
          stdout.writeAll([
            '\nUpdate available ',
            applyGrayColor(versions.current.toString()),
            ' → ',
            applyGreenColor(versions.latest.toString()),
            '\nRun ',
            applyLightBlueColor('dart pub global activate rps'),
            ' to update\n\n',
          ]);
          await Future.delayed(const Duration(seconds: 2));
        }
      } on Exception {
        // ignore
      }
    }

    if (args.length == 1 && args.first.trim() == '--version' ||
        args.first.trim() == '-v') {
      stdout
        ..writeln()
        ..writeln('📝 rps version: ${applyBold(package.version.toString())}')
        ..writeln();
      exit(0);
    } else if (args.length == 1 && args.first.trim() == '--help' ||
        args.first.trim() == '-h') {
      stdout.writeln(
        '${applyBold('Run Pubspec Script')} '
        '(${applyBoldGreen('rps')}) '
        '${applyBold("v${package.version}")}\n\n'
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
    stderr.writeln("${applyBoldRed('Error!')} ${err.message}");
    await stderr.flush();
    exit(1);
  } catch (err, st) {
    stderr.writeln("${applyBoldRed('Error!')} $err\n$st");
    await stderr.flush();
    exit(1);
  }
}
