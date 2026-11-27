import 'package:rps/rps.dart';
import 'package:rps/src/cli/arguments.dart';
import 'package:rps/src/utils/rps_package.dart';

/// Prints usage information.
void printHelp(Console console, RpsPackage package) {
  console
    ..writeln(
        '${bold('Run Pubspec Script')} (${boldGreen('rps')}) ${bold("v${package.version}")}')
    ..writeln()
    ..writeln('${bold('Usage')}:')
    ..writeln('  rps [options] <script> [arguments]')
    ..writeln('  rps [options] run <script> [arguments]')
    ..writeln('  rps ls [--json]')
    ..writeln()
    ..writeln('${bold('Options')}:')
    ..writeln(RpsArguments.optionsUsage)
    ..writeln()
    ..writeln('${bold('Commands')}:')
    ..writeln('  Call without arguments to select a script to run.')
    ..writeln('  ls [--json]                List all scripts. '
        'Add --json for machine-readable output.')
    ..writeln('  run <script> [arguments]   Run a script from pubspec.yaml '
        'or rps.yaml. "run" can be omitted.')
    ..writeln();
}
