import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:rps/commands/run_command.dart';
import 'package:rps/pubspec.dart';
import 'package:rps/rps.dart' as rps;
import 'package:rps/rps_exception.dart';

void main(List<String> args) async {
  final commandRunner = CommandRunner<int>('rps', 'Run Pubspec Script');

  try {
    final pubspec = await Pubspec.load(Directory.current);
    commandRunner
      ..addCommand(RunCommand(pubspec))
      ..argParser.addFlag(
        'version',
        negatable: false,
        help: 'Print the rps package version.',
      );

    final results = commandRunner.parse(args);

    if (results.wasParsed('version') && args.length == 1) {
      final ver = await rps.getPackageVersion();
      stdout.writeln('rps version: ${rps.applyBold(ver)}');
      exit(0);
    } else {
      try {
        final exitCode = await commandRunner.run(args);
        exit(exitCode ?? 1);
      } on UsageException catch (err) {
        if (err.message.contains('Could not find a command named')) {
          final exitCode = await commandRunner.run(['run', ...args]);
          exit(exitCode ?? 1);
        } else {
          rethrow;
        }
      }
    }
  } on RpsException catch (err) {
    stderr.writeln("${rps.applyBoldRed('Error!')} ${err.message}");
    exit(1);
  } catch (err, st) {
    stderr.writeln("${rps.applyBoldRed('Error!')} $err\n$st");
    exit(1);
  }
}
