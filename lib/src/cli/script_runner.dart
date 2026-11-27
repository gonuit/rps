import 'dart:io' as io;

import 'package:path/path.dart' as p;
import 'package:prompts/prompts.dart' as prompts;
import 'package:rps/rps.dart';
import 'package:rps/src/cli/executor.dart';
import 'package:rps/src/utils/env_file.dart';
import 'package:rps/src/utils/file_system.dart';

/// Asks the user a yes or no question.
typedef Confirm = bool Function(String message);

bool _ask(String message) {
  final answer = prompts.get(
    '$message (y/N)',
    chevron: false,
    validate: (answer) => true,
  );
  return answer.trim().toLowerCase().startsWith('y');
}

/// Prints and runs the commands of a resolved script.
class ScriptRunner {
  /// The executor used to run shell commands.
  final Executor executor;

  /// Where the progress is printed.
  final Console console;

  /// Whether commands are printed instead of being run.
  final bool dryRun;

  /// Whether scripts are confirmed without asking.
  final bool assumeYes;

  /// Whether the user can be asked questions.
  final bool interactive;

  final Confirm _confirm;
  final FileSystem _fs;
  final Map<String, String> _processEnvironment;
  final _envFiles = <String, Map<String, String>>{};

  /// Creates a [ScriptRunner].
  ScriptRunner({
    required this.executor,
    required this.console,
    this.dryRun = false,
    this.assumeYes = false,
    this.interactive = false,
    Confirm confirm = _ask,
    FileSystem fs = const SystemFileSystem(),
    Map<String, String>? processEnvironment,
  })  : _confirm = confirm,
        _fs = fs,
        _processEnvironment = processEnvironment ?? io.Platform.environment;

  /// Runs [events] in order and stops at the first command that fails.
  Future<void> run(List<ExecutionEvent> events) async {
    _confirmAll(events);
    for (final event in events) {
      switch (event) {
        case ConfirmationRequired():
          if (dryRun) {
            console.writeln('${bold(yellow('?'))} ${event.message}\n');
          }
        case CommandExecuted():
          await _execute(event);
        case CommandReferenced():
          _header(
            event.context,
            isHook: event.isHook,
            step: event.step,
            directory: null,
          );
          console.writeln('${boldGreen(r'$ rps')} ${bold(event.command)}\n');
      }
    }
  }

  void _confirmAll(List<ExecutionEvent> events) {
    if (dryRun || assumeYes) return;
    final confirmations = events.whereType<ConfirmationRequired>().toSet();
    for (final confirmation in confirmations) {
      if (!interactive) {
        throw RpsUsageException(
          'The script "${confirmation.path}" asks for confirmation: '
          '${confirmation.message}',
          hint: 'Run it with "rps --yes <script>" or set RPS_YES=1 to confirm.',
        );
      }
      if (!_confirm(confirmation.message)) throw RpsException('Cancelled.');
    }
    if (confirmations.isNotEmpty) console.writeln();
  }

  void _header(
    Context context, {
    required bool isHook,
    required (int, int)? step,
    required String? directory,
  }) {
    final basePath = context.basePath;
    if (isHook) {
      basePath.last = blue(basePath.last.substring(1));
    }
    console.writeln([
      boldGreen('>'),
      ...basePath,
      if (step != null) gray('[${step.$1}/${step.$2}]'),
      if (directory != null) gray('($directory)'),
    ].join(' '));
  }

  String? _workingDirectory(CommandExecuted event) {
    final directory = event.workingDirectory;
    if (directory == null) return null;
    final path = p.normalize(p.join(_fs.currentDirectoryPath, directory));
    if (!_fs.directoryExists(path)) {
      throw RpsConfigException(
        'The working directory "$directory" of the script '
        '"${event.context.basePath.join(' ')}" does not exist.',
      );
    }
    return path;
  }

  Map<String, String> _envFile(String file) {
    return _envFiles.putIfAbsent(file, () {
      final path = p.normalize(p.join(_fs.currentDirectoryPath, file));
      if (!_fs.fileExists(path)) {
        throw RpsConfigException('The env file "$file" does not exist.');
      }
      return parseEnvFile(_fs.readFile(path), path: file);
    });
  }

  Map<String, String>? _environment(CommandExecuted event) {
    final environment = <String, String>{};
    for (final file in event.envFiles) {
      for (final MapEntry(key: name, :value) in _envFile(file).entries) {
        if (!_processEnvironment.containsKey(name)) environment[name] = value;
      }
    }
    environment.addAll(event.environment);
    return environment.isEmpty ? null : environment;
  }

  Future<void> _execute(CommandExecuted event) async {
    _header(
      event.context,
      isHook: event.isHook,
      step: event.step,
      directory: event.workingDirectory,
    );
    final command = event.compile(shell: executor.shell);
    console.writeln('${boldGreen(r'$')} ${bold(command)}\n');
    if (dryRun) return;

    final exitCode = await executor.execute(
      command,
      environment: _environment(event),
      workingDirectory: _workingDirectory(event),
    );
    if (exitCode != 0) {
      throw ScriptFailedException(
        'Command ended with a non zero exit code ($exitCode).',
        exitCode: exitCode,
      );
    }
    console.writeln();
  }
}
