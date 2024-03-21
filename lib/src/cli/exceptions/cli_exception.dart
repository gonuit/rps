class CliException implements Exception {
  final String message;
  final Exception? error;
  final StackTrace? stackTrace;
  final int exitCode;

  CliException(
    this.message, {
    this.exitCode = 1,
    this.error,
    this.stackTrace,
  });
}
