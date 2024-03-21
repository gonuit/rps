import 'package:rps/rps.dart';

class CommandReferenced extends ExecutionEvent {
  @override
  final Context context;

  final String label;

  @override
  String get path => context.basePath.join(' ');
  @override
  final String command;

  CommandReferenced({
    required this.context,
    required this.command,
    required this.label,
  });

  @override
  bool operator ==(Object other) {
    return other is CommandReferenced && other.command == command && other.path == path && other.label == label;
  }

  @override
  int get hashCode => Object.hash(path, command, label, runtimeType);
}
