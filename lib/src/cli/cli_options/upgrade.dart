import 'dart:async';

import 'package:rps/rps.dart';
import 'package:rps/src/cli/cli.dart';
import 'package:rps/src/cli/cli_options/cli_option.dart';

import '../exceptions/cli_exception.dart';

class UpgradeOption extends CliOption {
  const UpgradeOption();

  @override
  String get description => 'Updates rps to latest version.';

  @override
  String get name => 'upgrade';

  @override
  String? get short => 'u';

  @override
  Future<void> run(Cli cli, Console console, List<String> arguments) async {
    const command = 'dart pub global activate rps';
    console.write(
      '${boldBlue('\n⏳ Upgrading rps package...')}\n\n'
      '${boldGreen(r'$')} ${bold(command)}\n\n',
    );

    final exitCode = await execute(command);
    if (exitCode > 0) {
      throw CliException(
        'Failed to update the rps package. '
        'Command ended with a non zero exit code.',
        exitCode: exitCode,
      );
    } else {
      console
        ..writeln()
        ..writeln(boldGreen('✓ rps updated successfully!'))
        ..writeln();
    }
  }
}
