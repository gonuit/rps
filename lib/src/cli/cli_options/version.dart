import 'package:rps/rps.dart';
import 'package:rps/src/utils/rps_package.dart';

/// Prints the current rps version.
void printVersion(Console console, RpsPackage package) {
  console
    ..writeln()
    ..writeln('📝 rps version: ${bold(package.version.toString())}')
    ..writeln();
}
