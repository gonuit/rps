import 'package:meta/meta.dart';
import 'package:rps/rps.dart';

/// Base class for all script execution events.
@immutable
abstract class ExecutionEvent {
  /// Creates an [ExecutionEvent].
  /// The context in which this event was resolved.
  Context get context;

  /// The full script path for this event.
  String get path;

  /// The shell command to execute, or null for structural events.
  String? get command;
}
