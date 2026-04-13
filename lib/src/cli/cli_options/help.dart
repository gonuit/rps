import 'dart:async';

import 'package:rps/rps.dart';
import 'package:rps/src/cli/cli.dart';
import 'package:rps/src/cli/cli_options/cli_option.dart';
import 'package:rps/src/utils/rps_package.dart';

/// The --help / -h option that prints usage information.
class HelpOption extends CliOption {
  /// Console used for output.
  final Console console;

  /// Package metadata for the version header.
  final RpsPackage package;

  /// Creates a [HelpOption].
  HelpOption({
    required this.console,
    required this.package,
  });

  @override
  String get description => 'Prints help.';

  @override
  String get name => 'help';

  @override
  String get short => 'h';

  @override
  Future<void> run(Cli cli, Console console, List<String> arguments) async {
    console
      ..writeln(
          '${bold('Run Pubspec Script')} (${boldGreen('rps')}) ${bold("v${package.version}")}')
      ..writeln();

    final options = cli.options;
    if (options.isNotEmpty) {
      console.writeln('${bold('Options')}:');
      for (final option in options) {
        final short = option.short;

        if (short != null) {
          console.writeln(
              '  -${option.short}, --${option.name} - ${option.description}');
        } else {
          console.writeln('      --${option.name} - ${option.description}');
        }
      }
    }

    final commands = cli.commands;
    if (commands.isNotEmpty) {
      console.writeln('${bold('Commands')}:');
      for (final command in commands) {
        if (command.name != null) {
          console.writeln(
              '  ${command.tooltip ?? command.name} - ${command.description}');
        } else {
          console.writeln('  ${command.description}');
        }
      }
    }

    console.writeln();
  }
}
