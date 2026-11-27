/// General-purpose exception for rps errors.
class RpsException implements Exception {
  /// Human-readable error message.
  final String message;

  /// Optional underlying exception.
  final Exception? error;

  /// Optional stack trace from the underlying error.
  final StackTrace? stackTrace;

  /// Creates an [RpsException].
  RpsException(this.message, [this.error, this.stackTrace]);

  /// Exit code of rps when it ends with this exception.
  int get exitCode => 1;

  @override
  String toString() {
    return 'RpsException: $message';
  }
}

/// A script that does not exist or is called with the wrong arguments.
class RpsUsageException extends RpsException {
  /// Creates an [RpsUsageException].
  RpsUsageException(super.message, [super.error, super.stackTrace]);

  @override
  int get exitCode => 64;
}

/// A problem in the `pubspec.yaml` or `rps.yaml` file.
class RpsConfigException extends RpsException {
  /// Creates an [RpsConfigException].
  RpsConfigException(super.message, [super.error, super.stackTrace]);

  @override
  int get exitCode => 78;
}
