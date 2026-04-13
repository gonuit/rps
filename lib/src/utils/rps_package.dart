import 'dart:io';
import 'dart:isolate';

import 'package:pub_semver/pub_semver.dart';
import 'package:rps/rps.dart';
import 'package:rps/src/config/rps_config.dart';

/// Provides metadata about the rps package itself.
class RpsPackage {
  final Pubspec _pubspec;
  final RpsConfig _config;

  /// The current package version.
  Version get version => Version.parse(_pubspec.packageVersion);

  /// The package name.
  String get name => _pubspec.packageName;

  /// The persisted configuration.
  RpsConfig get config => _config;

  /// Creates an [RpsPackage].
  RpsPackage({
    required Pubspec pubspec,
    required RpsConfig config,
  })  : _pubspec = pubspec,
        _config = config;

  /// Loads the rps package from its installed location.
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
