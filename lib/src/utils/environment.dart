import 'dart:io';

/// Provides information about the runtime environment.
abstract interface class Environment {
  /// Whether the process is running in a CI environment.
  bool get isCI;
}

/// Default [Environment] backed by platform environment variables.
class SystemEnvironment implements Environment {
  /// Creates a [SystemEnvironment].
  const SystemEnvironment();

  @override
  bool get isCI => isCIValue(Platform.environment['CI']);

  /// Whether [value] of the `CI` variable marks a CI environment.
  static bool isCIValue(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    return normalized.isNotEmpty && normalized != 'false' && normalized != '0';
  }
}
