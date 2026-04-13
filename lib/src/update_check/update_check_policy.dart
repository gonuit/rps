/// Rules for when to check for updates and when to show alerts.
class UpdateCheckPolicy {
  /// How long a cached version check result is considered fresh.
  final Duration cacheTtl;

  /// Minimum interval between update alerts.
  final Duration alertCooldown;

  /// Creates an [UpdateCheckPolicy].
  const UpdateCheckPolicy({
    this.cacheTtl = const Duration(days: 1),
    this.alertCooldown = const Duration(days: 1),
  });

  /// Returns `true` if the cache has expired.
  bool shouldRefreshCache(DateTime? lastCheckedAt, DateTime now) {
    if (lastCheckedAt == null) return true;
    return now.difference(lastCheckedAt) >= cacheTtl;
  }

  /// Returns `true` if enough time has passed to show another alert.
  bool shouldShowAlert(DateTime? lastAlertAt, DateTime now) {
    if (lastAlertAt == null) return true;
    return now.difference(lastAlertAt) >= alertCooldown;
  }
}
