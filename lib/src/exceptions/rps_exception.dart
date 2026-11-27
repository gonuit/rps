/// Exit codes of rps for its own errors.
abstract final class ExitCodes {
  /// Any error that has no code of its own.
  static const error = 1;

  /// A script that does not exist or is called with the wrong arguments.
  static const usage = 64;

  /// A problem in the `pubspec.yaml` or `rps.yaml` file.
  static const config = 78;
}

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
  int get exitCode => ExitCodes.error;

  @override
  String toString() {
    return 'RpsException: $message';
  }
}

/// A script that does not exist or is called with the wrong arguments.
class RpsUsageException extends RpsException {
  /// What the user can do next.
  final String hint;

  /// Creates an [RpsUsageException].
  RpsUsageException(
    super.message, {
    this.hint = 'Run "rps ls" to see the available scripts.',
  });

  @override
  int get exitCode => ExitCodes.usage;
}

/// A problem in the `pubspec.yaml` or `rps.yaml` file.
class RpsConfigException extends RpsException {
  /// Creates an [RpsConfigException].
  RpsConfigException(super.message, [super.error, super.stackTrace]);

  @override
  int get exitCode => ExitCodes.config;
}

/// A script or hook that ended with a non-zero exit code.
class ScriptFailedException extends RpsException {
  @override
  final int exitCode;

  /// Creates a [ScriptFailedException].
  ScriptFailedException(super.message, {required this.exitCode});
}
