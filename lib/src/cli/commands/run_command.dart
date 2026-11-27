import 'dart:async';

import 'package:collection/collection.dart';
import 'package:rps/rps.dart';

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

  List<String> _withoutCommandName(
    ScriptsParser parser,
    List<String> arguments,
  ) {
    if (arguments.firstOrNull != 'run') return arguments;
    final rest = arguments.skip(1).toList();
    final isNestedUnderRun = rest.isNotEmpty &&
        !parser.contains([rest.first]) &&
        parser.contains(['run', rest.first]);
    return isNestedUnderRun ? arguments : rest;
  }

  /// Runs the script that [arguments] point to, with its hooks.
  Future<void> run(List<String> arguments) async {
    final source = await _getScriptsSource();
    final parser = ScriptsParser(source: source, platform: _platform);

    final events = parser.getCommandsToExecute(
      _withoutCommandName(parser, arguments),
    );

    if (events.isEmpty) {
      throw RpsUsageException(
        'Missing script. Command: "${arguments.join(' ')}".',
      );
    }

    await runner.run(events);
  }
}
