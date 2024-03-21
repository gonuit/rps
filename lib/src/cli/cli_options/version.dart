import 'dart:async';

import 'package:rps/rps.dart';
import 'package:rps/src/cli/cli.dart';
import 'package:rps/src/cli/cli_options/cli_option.dart';

class VersionOption extends CliOption {
  const VersionOption();

  @override
  String get description => 'Prints rps version.';

  @override
  String get name => 'version';

  @override
  String? get short => null;

  @override
  Future<void> run(Cli cli, Console console, List<String> arguments) async {
    console
      ..writeln()
      ..writeln('📝 rps version: ${bold(cli.package.version.toString())}')
      ..writeln();
  }
}
