import 'package:rps/rps.dart';
import 'package:rps/src/cli/executor.dart';

/// Prints and runs the commands of a resolved script.
class ScriptRunner {
  /// The executor used to run shell commands.
  final Executor executor;

  /// Where the progress is printed.
  final Console console;

  /// Whether commands are printed instead of being run.
  final bool dryRun;

  /// Creates a [ScriptRunner].
  ScriptRunner({
    required this.executor,
    required this.console,
    this.dryRun = false,
  });

  /// Runs [events] in order and stops at the first command that fails.
  Future<void> run(List<ExecutionEvent> events) async {
    for (final event in events) {
      switch (event) {
        case CommandExecuted():
          await _execute(event);
        case CommandReferenced():
          _header(event.context, isHook: event.isHook);
          console.writeln('${boldGreen(r'$ rps')} ${bold(event.command)}\n');
      }
    }
  }

  void _header(Context context, {required bool isHook}) {
    final basePath = context.basePath;
    if (isHook) {
      basePath.last = blue(basePath.last.substring(1));
    }
    console.writeln('${boldGreen('>')} ${basePath.join(' ')}');
  }

  Future<void> _execute(CommandExecuted event) async {
    _header(event.context, isHook: event.isHook);
    final command = event.compile(shell: executor.shell);
    console.writeln('${boldGreen(r'$')} ${bold(command)}\n');
    if (dryRun) return;

    final exitCode = await executor.execute(command);
    if (exitCode != 0) {
      throw ScriptFailedException(
        'Command ended with a non zero exit code ($exitCode).',
        exitCode: exitCode,
      );
    }
    console.writeln();
  }
}
