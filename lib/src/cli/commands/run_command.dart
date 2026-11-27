import 'dart:async';

import 'package:collection/collection.dart';
import 'package:rps/rps.dart';
import 'package:rps/src/cli/executor.dart';
import 'package:rps/src/cli/script_runner.dart';
import 'package:rps/src/utils/file_system.dart';
import 'package:rps/src/utils/platform.dart' show Platform;

/// The `run` command that executes a script defined in pubspec.yaml.
class RunCommand {
  final FutureOr<ScriptsSource> Function() _getScriptsSource;

  /// The executor used to run shell commands.
  final Executor executor;

  /// Whether commands are printed instead of being run.
  final bool dryRun;

  /// Whether scripts are confirmed without asking.
  final bool assumeYes;

  /// Whether the user can be asked questions.
  final bool interactive;

  final Platform _platform;

  final FileSystem _fs;

  /// Creates a [RunCommand].
  RunCommand({
    required this.executor,
    this.dryRun = false,
    this.assumeYes = false,
    this.interactive = false,
    required FutureOr<ScriptsSource> Function() getScriptsSource,
    required Platform platform,
    FileSystem fs = const SystemFileSystem(),
  })  : _getScriptsSource = getScriptsSource,
        _platform = platform,
        _fs = fs;

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
  ///
  /// The error output of commands run at the same time goes to [errors].
  Future<void> run(
    Console console,
    List<String> arguments, {
    Console? errors,
  }) async {
    final source = await _getScriptsSource();
    final parser = ScriptsParser(source: source, platform: _platform);

    final events = _resolve(parser, arguments);

    if (events.isEmpty) {
      throw RpsUsageException(
        'Missing script. Command: "${arguments.join(' ')}".',
      );
    }

    await ScriptRunner(
      executor: executor,
      console: console,
      errors: errors,
      dryRun: dryRun,
      assumeYes: assumeYes,
      interactive: interactive,
      fs: _fs,
    ).run(events);
  }
}
