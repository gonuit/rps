import 'package:rps/rps.dart';

class HookExecuted extends ExecutionEvent {
  @override
  final Context context;

  final String name;

  @override
  String get path => context.path.join(' ');
  @override
  final String command;

  HookExecuted({
    required this.context,
    required this.command,
    required this.name,
  });

  @override
  bool operator ==(Object other) {
    return other is HookExecuted &&
        other.command == command &&
        other.path == path &&
        other.name == name;
  }

  @override
  int get hashCode => Object.hash(path, command, name, runtimeType);
}
