class RpsException implements Exception {
  final String message;
  final Exception? error;
  final StackTrace? stackTrace;

  RpsException(this.message, [this.error, this.stackTrace]);

  @override
  String toString() {
    return 'RpsException: $message';
  }
}
