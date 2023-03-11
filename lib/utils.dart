import 'dart:io';
import 'dart:isolate';

import 'package:rps/pubspec.dart';

String applyRedColor(String text) => '\x1B[31m$text\x1B[0m';
String applyGreenColor(String text) => '\x1B[32m$text\x1B[0m';
String applyBlueColor(String text) => '\x1B[34m$text\x1B[0m';
String applyBold(String text) => '\x1b[1m$text\x1b[0m';
String applyBoldRed(String text) => applyBold(applyRedColor(text));
String applyBoldGreen(String text) => applyBold(applyGreenColor(text));
String applyBoldBlue(String text) => applyBold(applyBlueColor(text));

Future<String> getPackageVersion() async {
  const rootLibrary = 'package:rps/rps.dart';
  final uri = await Isolate.resolvePackageUri(Uri.parse(rootLibrary));
  if (uri == null) {
    print('Library cannot be loaded.');
    exit(1);
  }

  final root = uri.resolve('..');
  final pubspec = await Pubspec.load(Directory.fromUri(root));
  return pubspec.packageVersion!;
}
