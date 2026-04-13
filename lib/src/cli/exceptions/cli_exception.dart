/// Exception thrown when a CLI command fails.
class CliException implements Exception {
  /// Human-readable error message.
  final String message;

  /// Optional underlying exception.
  final Exception? error;

  /// Optional stack trace from the underlying error.
  final StackTrace? stackTrace;

  /// Process exit code to use when this exception is thrown.
  final int exitCode;

  /// Creates a [CliException].
  CliException(
    this.message, {
    this.exitCode = 1,
    this.error,
    this.stackTrace,
  });
}
