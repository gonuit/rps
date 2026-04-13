import 'package:pub_semver/pub_semver.dart';

/// The result of comparing the current version against the latest on pub.dev.
class UpdateCheckResult {
  /// The currently installed version.
  final Version current;

  /// The latest version available on pub.dev.
  final Version latest;

  /// Creates an [UpdateCheckResult].
  const UpdateCheckResult({
    required this.current,
    required this.latest,
  });

  /// Returns `true` if a newer version is available.
  bool get hasUpdate => latest > current;
}
