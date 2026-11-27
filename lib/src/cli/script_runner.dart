import 'dart:async';
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:rps/rps.dart';
import 'package:rps/src/utils/env_file.dart';

class _Cancelled implements Exception {
  const _Cancelled();
}

class _Branch {
  static const _colors = [lightBlue, violet, green, yellow, blue];

  final String label;
  final int width;
  final int color;
  final Future<void> cancelled;
  var isCancelled = false;

  _Branch({
    required this.label,
    required this.width,
    required this.color,
    required this.cancelled,
  }) {
    cancelled.then((_) => isCancelled = true).ignore();
  }

  String get prefix =>
      _colors[color % _colors.length]('[${label.padRight(width)}]');
}

/// Prints and runs the commands of a resolved script.
class ScriptRunner {
  /// The executor used to run shell commands.
  final Executor executor;

  /// Where the progress is printed.
  final Console console;

  /// Where the error output of commands run at the same time is printed.
  final Console errors;

  /// Whether commands are printed instead of being run.
  final bool dryRun;

  /// Whether scripts are confirmed without asking.
  final bool assumeYes;

  /// Whether the user can be asked questions.
  final bool interactive;

  /// Asks the questions of scripts that need confirmation.
  final Prompt prompt;

  final FileSystem _fs;
  final Map<String, String> _processEnvironment;
  final _envFiles = <String, Map<String, String>>{};

  /// Creates a [ScriptRunner].
  ScriptRunner({
    required this.executor,
    required this.console,
    Console? errors,
    this.dryRun = false,
    this.assumeYes = false,
    this.interactive = false,
    Prompt? prompt,
    FileSystem fs = const SystemFileSystem(),
    Map<String, String>? processEnvironment,
  })  : errors = errors ?? console,
        prompt = prompt ?? TerminalPrompt(console),
        _fs = fs,
        _processEnvironment = processEnvironment ?? io.Platform.environment;

  /// Runs [events] in order and stops at the first command that fails.
  Future<void> run(List<ExecutionEvent> events) async {
    _confirmAll(events);
    await _run(events, null);
  }

  Future<void> _run(List<ExecutionEvent> events, _Branch? branch) async {
    for (final event in events) {
      if (branch != null && branch.isCancelled) throw const _Cancelled();
      switch (event) {
        case ConfirmationRequired():
          if (dryRun) {
            _print(branch, '${bold(yellow('?'))} ${event.message}\n');
          }
        case CommandExecuted():
          await _execute(event, branch);
        case CommandReferenced():
          _header(
            branch,
            event.context,
            isHook: event.isHook,
            step: event.step,
            directory: null,
          );
          _print(branch, '${boldGreen(r'$ rps')} ${bold(event.command)}\n');
        case ParallelExecuted():
          await _parallel(event, branch);
      }
    }
  }

  Iterable<ExecutionEvent> _flatten(List<ExecutionEvent> events) sync* {
    for (final event in events) {
      yield event;
      if (event is ParallelExecuted) {
        for (final branch in event.branches) {
          yield* _flatten(branch.events);
        }
      }
    }
  }

  void _confirmAll(List<ExecutionEvent> events) {
    if (dryRun || assumeYes) return;
    final confirmations =
        _flatten(events).whereType<ConfirmationRequired>().toSet();
    for (final confirmation in confirmations) {
      if (!interactive) {
        throw RpsUsageException(
          'The script "${confirmation.path}" asks for confirmation: '
          '${confirmation.message}',
          hint: 'Run it with "rps --yes <script>" or set RPS_YES=1 to confirm.',
        );
      }
      final answer = prompt.ask('${confirmation.message} (y/N)');
      if (!answer.trim().toLowerCase().startsWith('y')) {
        throw RpsException('Cancelled.');
      }
    }
    if (confirmations.isNotEmpty) console.writeln();
  }

  void _print(_Branch? branch, String text) {
    if (branch == null) {
      console.writeln(text);
      return;
    }
    for (final line in text.trimRight().split('\n')) {
      console.writeln('${branch.prefix} $line');
    }
  }

  void _header(
    _Branch? branch,
    Context context, {
    required bool isHook,
    required (int, int)? step,
    required String? directory,
  }) {
    final basePath = context.basePath;
    if (isHook) {
      basePath.last = blue(basePath.last.substring(1));
    }
    _print(
      branch,
      [
        boldGreen('>'),
        ...basePath,
        if (step != null) gray('[${step.$1}/${step.$2}]'),
        if (directory != null) gray('($directory)'),
      ].join(' '),
    );
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

  Future<void> _execute(CommandExecuted event, _Branch? branch) async {
    _header(
      branch,
      event.context,
      isHook: event.isHook,
      step: event.step,
      directory: event.workingDirectory,
    );
    final command = event.compile(shell: executor.shell);
    _print(branch, '${boldGreen(r'$')} ${bold(command)}\n');
    if (dryRun) return;

    final exitCode = await executor.execute(
      command,
      environment: _environment(event),
      workingDirectory: _workingDirectory(event),
      output: branch == null
          ? null
          : CommandOutput(
              onOutput: (line) => console.writeln('${branch.prefix} $line'),
              onError: (line) => errors.writeln('${branch.prefix} $line'),
              cancelled: branch.cancelled,
            ),
    );
    if (branch != null && branch.isCancelled) throw const _Cancelled();
    if (exitCode != 0) {
      throw ScriptFailedException(
        branch == null
            ? 'Command ended with a non zero exit code ($exitCode).'
            : 'The command "${branch.label}" ended with '
                'a non zero exit code ($exitCode).',
        exitCode: exitCode,
      );
    }
    if (branch == null) console.writeln();
  }

  Future<void> _parallel(ParallelExecuted event, _Branch? parent) async {
    final count = event.branches.length;
    _print(
      parent,
      '${boldGreen('>')} ${event.path} ${gray('($count in parallel)')}\n',
    );

    final cancel = Completer<void>();
    void stop() {
      if (!cancel.isCompleted) cancel.complete();
    }

    parent?.cancelled.then((_) => stop()).ignore();
    final labels = [
      for (final branch in event.branches)
        [if (parent != null) parent.label, branch.label].join(' '),
    ];
    final width = labels.map((label) => label.length).reduce(math.max);
    final branches = [
      for (final (index, label) in labels.indexed)
        _Branch(
          label: label,
          width: width,
          color: index,
          cancelled: cancel.future,
        ),
    ];

    (Object, StackTrace)? failure;
    Future<void> runBranch(int index) async {
      try {
        await _run(event.branches[index].events, branches[index]);
      } on _Cancelled {
        return;
      } catch (error, stackTrace) {
        failure ??= (error, stackTrace);
        stop();
      }
    }

    if (dryRun) {
      for (var index = 0; index < count; index++) {
        await runBranch(index);
      }
    } else {
      await Future.wait([
        for (var index = 0; index < count; index++) runBranch(index),
      ]);
    }

    if (failure case (final error, final stackTrace)) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    if (parent != null && parent.isCancelled) throw const _Cancelled();
    if (parent == null) console.writeln();
  }
}
