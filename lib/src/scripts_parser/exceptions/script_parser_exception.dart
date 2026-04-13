/// Exception thrown when the script parser encounters an error.
class ScriptParserException implements Exception {
  /// Human-readable error message.
  final String message;

  /// Creates a [ScriptParserException].
  ScriptParserException(this.message);
}
