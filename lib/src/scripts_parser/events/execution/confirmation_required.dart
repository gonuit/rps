import 'package:rps/rps.dart';

/// An execution event of a script that asks for confirmation before it runs.
class ConfirmationRequired extends ExecutionEvent {
  @override
  final Context context;

  /// The question shown to the user.
  final String message;

  @override
  String get path => context.basePath.join(' ');

  @override
  String? get command => null;

  /// Creates a [ConfirmationRequired].
  ConfirmationRequired({required this.context, required this.message});

  @override
  bool operator ==(Object other) {
    return other is ConfirmationRequired &&
        other.path == path &&
        other.message == message;
  }

  @override
  int get hashCode => Object.hash(path, message, runtimeType);
}
