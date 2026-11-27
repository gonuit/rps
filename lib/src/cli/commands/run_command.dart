import 'dart:async';

import 'package:collection/collection.dart';
import 'package:rps/rps.dart';
import 'package:rps/src/cli/executor.dart';
import 'package:rps/src/utils/platform.dart' show Platform;

/// The `run` command that executes a script defined in pubspec.yaml.
class RunCommand {
  final FutureOr<ScriptsSource> Function() _getScriptsSource;

  /// The executor used to run shell commands.
  final Executor executor;

  /// Whether commands are printed instead of being run.
  final bool dryRun;

  final Platform _platform;

  /// Creates a [RunCommand].
  RunCommand({
    required this.executor,
    this.dryRun = false,
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
  Future<void> run(Console console, List<String> arguments) async {
    final source = await _getScriptsSource();
    final parser = ScriptsParser(source: source, platform: _platform);

    final events = _resolve(parser, arguments);

    if (events.isEmpty) {
      throw RpsUsageException(
        'Missing script. Command: "${arguments.join(' ')}".',
      );
    }

    for (final event in events) {
      if (event is CommandExecuted) {
        final basePath = event.context.basePath;
        if (event.isHook) {
          basePath.last = blue(basePath.last.substring(1));
        }
        console.writeln('${boldGreen('>')} ${basePath.join(' ')}');
        final command = event.compile(shell: executor.shell);
        console.writeln('${boldGreen(r'$')} ${bold(command)}\n');
        if (dryRun) continue;
        final exitCode = await executor.execute(command);

        if (exitCode != 0) {
          throw ScriptFailedException(
            'Command ended with a non zero exit code ($exitCode).',
            exitCode: exitCode,
          );
        }
        console.writeln();
      } else if (event is CommandReferenced) {
        final basePath = event.context.basePath;
        if (event.isHook) {
          basePath.last = blue(basePath.last.substring(1));
        }
        console.writeln('${boldGreen('>')} ${basePath.join(' ')}');
        console.writeln('${boldGreen(r'$ rps')} ${bold(event.command)}\n');
      } else if (event is HookExecuted) {
        // No output for hook events.
      }
    }
  }
}
