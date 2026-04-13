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

  @override
  String toString() {
    return 'RpsException: $message';
  }
}
