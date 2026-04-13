import 'dart:io' as io;

/// Abstraction over platform identification for testability.
abstract interface class Platform {
  /// Whether the current platform is Windows.
  bool get isWindows;

  /// Whether the current platform is macOS.
  bool get isMacOS;

  /// Whether the current platform is Linux.
  bool get isLinux;

  /// The operating system name (e.g. `'linux'`, `'macos'`, `'windows'`).
  String get operatingSystem;
}

/// Default [Platform] backed by `dart:io`.
class SystemPlatform implements Platform {
  /// Creates a [SystemPlatform].
  const SystemPlatform();

  @override
  bool get isWindows => io.Platform.isWindows;

  @override
  bool get isMacOS => io.Platform.isMacOS;

  @override
  bool get isLinux => io.Platform.isLinux;

  @override
  String get operatingSystem => io.Platform.operatingSystem;
}
