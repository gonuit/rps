/// Interface for providing scripts data to the parser.
abstract class ScriptsSource {
  /// Returns the raw scripts data (typically a Map or String).
  dynamic getScripts();
}
