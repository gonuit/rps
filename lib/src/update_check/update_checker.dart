import 'package:pub_semver/pub_semver.dart';

import 'package:rps/src/config/rps_config.dart';
import 'package:rps/src/update_check/clock.dart';
import 'package:rps/src/update_check/pub_dev_api.dart';
import 'package:rps/src/update_check/update_check_policy.dart';
import 'package:rps/src/update_check/update_check_result.dart';

/// Checks pub.dev for newer versions and manages cache / alert cooldown.
class UpdateChecker {
  final Version _currentVersion;
  final String _packageName;
  final PubDevApi _api;
  final RpsConfig _config;
  final Clock _clock;
  final UpdateCheckPolicy _policy;
  final Duration _networkTimeout;

  /// Creates an [UpdateChecker].
  UpdateChecker({
    required Version currentVersion,
    required String packageName,
    required PubDevApi api,
    required RpsConfig config,
    required Clock clock,
    UpdateCheckPolicy policy = const UpdateCheckPolicy(),
    Duration networkTimeout = const Duration(milliseconds: 300),
  })  : _currentVersion = currentVersion,
        _packageName = packageName,
        _api = api,
        _config = config,
        _clock = clock,
        _policy = policy,
        _networkTimeout = networkTimeout;

  /// Returns a non-null result only when the alert cooldown has expired
  /// and a newer version is available.
  Future<UpdateCheckResult?> check() async {
    final now = _clock.now();

    if (!_policy.shouldShowAlert(_config.data.lastUpdateAlertAt, now)) {
      return null;
    }

    final latest = await _resolveLatestVersion(now);
    if (latest == null) return null;

    final result = UpdateCheckResult(
      current: _currentVersion,
      latest: latest,
    );
    return result.hasUpdate ? result : null;
  }

  /// Records that the update alert was shown to prevent repeated alerts.
  void markAlertShown() {
    _config.update(_config.data.copyWith(
      lastUpdateAlertAt: _clock.now(),
    ));
  }

  Future<Version?> _resolveLatestVersion(DateTime now) async {
    final cached = _config.data.latestVersion;
    final cachedAt = _config.data.updateCheckedAt;

    if (cached != null && !_policy.shouldRefreshCache(cachedAt, now)) {
      return cached;
    }

    final rawVersion =
        await _api.getLastVersion(_packageName).timeout(_networkTimeout);
    final parsed = Version.parse(rawVersion);

    _config.update(_config.data.copyWith(
      updateCheckedAt: _clock.now(),
      latestVersion: parsed,
    ));

    return parsed;
  }
}
