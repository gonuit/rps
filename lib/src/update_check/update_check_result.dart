import 'package:pub_semver/pub_semver.dart';

class UpdateCheckResult {
  final Version current;
  final Version latest;

  const UpdateCheckResult({
    required this.current,
    required this.latest,
  });

  bool get hasUpdate => latest > current;
}
