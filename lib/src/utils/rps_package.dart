import 'dart:io';
import 'dart:isolate';

import 'package:pub_semver/pub_semver.dart';
import 'package:rps/rps.dart';
import 'package:rps/src/config/rps_config.dart';

class RpsPackage {
  final Pubspec _pubspec;
  final RpsConfig _config;

  Version get version => Version.parse(_pubspec.packageVersion);
  String get name => _pubspec.packageName;
  RpsConfig get config => _config;

  RpsPackage({
    required Pubspec pubspec,
    required RpsConfig config,
  })  : _pubspec = pubspec,
        _config = config;

  static Future<RpsPackage> load() async {
    final directory = await _getPackageDirectory();
    return RpsPackage(
      pubspec: Pubspec.load(directory),
      config: RpsConfig.load(directory),
    );
  }

  static Future<Directory> _getPackageDirectory() async {
    const rootLibrary = 'package:rps/rps.dart';
    final uri = await Isolate.resolvePackageUri(Uri.parse(rootLibrary));
    if (uri == null) {
      throw RpsException('Library cannot be loaded.');
    }
    return Directory.fromUri(uri.resolve('..'));
  }
}
