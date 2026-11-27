import 'dart:async';

import 'package:collection/collection.dart';
import 'package:rps/rps.dart';
import 'package:rps/src/utils/platform.dart' show Platform;

/// The `run` command that executes a script defined in pubspec.yaml.
class RunCommand {
  final FutureOr<ScriptsSource> Function() _getScriptsSource;

  /// Runs the commands of the script.
  final ScriptRunner runner;

  final Platform _platform;

  /// Creates a [RunCommand].
  RunCommand({
    required this.runner,
    required FutureOr<ScriptsSource> Function() getScriptsSource,
    required Platform platform,
  })  : _getScriptsSource = getScriptsSource,
        _platform = platform;

  List<ExecutionEvent> _resolve(ScriptsParser parser, List<String> arguments) {
    if (arguments.firstOrNull != 'run') {
      return parser.getCommandsToExecute(arguments);
    }
    try {
      // Remove command name (run) from arguments list
      return parser.getCommandsToExecute(arguments.skip(1).toList());
    } on RpsException {
      try {
        return parser.getCommandsToExecute(arguments);
      } on RpsException catch (_) {}
      rethrow;
    }
  }

  /// Runs the script that [arguments] point to, with its hooks.
  Future<void> run(List<String> arguments) async {
    final source = await _getScriptsSource();
    final parser = ScriptsParser(source: source, platform: _platform);

    final events = _resolve(parser, arguments);

    if (events.isEmpty) {
      throw RpsUsageException(
        'Missing script. Command: "${arguments.join(' ')}".',
      );
    }

    await runner.run(events);
  }
}
