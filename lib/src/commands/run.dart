import 'dart:async';

import 'package:args/command_runner.dart';

class RunCommand extends Command {
  @override
  String get description =>
      'This runs an arbitrary command from a pubspec\'s "scripts" object. '
      'If no "command" is provided, it will list the available scripts.';

  @override
  String get name => 'run';

  @override
  Future<void> run() async {
    final args = argResults;
    if (args == null) {
      throw ArgumentError('Cannot read arguments.');
    }
  }
}
