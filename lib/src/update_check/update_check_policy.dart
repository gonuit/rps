// Pure rules for when to check for updates and when to alert.
class UpdateCheckPolicy {
  final Duration cacheTtl;
  final Duration alertCooldown;

  const UpdateCheckPolicy({
    this.cacheTtl = const Duration(days: 1),
    this.alertCooldown = const Duration(days: 1),
  });

  bool shouldRefreshCache(DateTime? lastCheckedAt, DateTime now) {
    if (lastCheckedAt == null) return true;
    return now.difference(lastCheckedAt) >= cacheTtl;
  }

  bool shouldShowAlert(DateTime? lastAlertAt, DateTime now) {
    if (lastAlertAt == null) return true;
    return now.difference(lastAlertAt) >= alertCooldown;
  }
}
