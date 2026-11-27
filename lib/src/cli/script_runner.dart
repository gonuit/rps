import 'dart:io' as io;

import 'package:path/path.dart' as p;
import 'package:rps/rps.dart';
import 'package:rps/src/cli/executor.dart';
import 'package:rps/src/utils/env_file.dart';
import 'package:rps/src/utils/file_system.dart';

/// Prints and runs the commands of a resolved script.
class ScriptRunner {
  /// The executor used to run shell commands.
  final Executor executor;

  /// Where the progress is printed.
  final Console console;

  /// Whether commands are printed instead of being run.
  final bool dryRun;

  final FileSystem _fs;
  final Map<String, String> _processEnvironment;
  final _envFiles = <String, Map<String, String>>{};

  /// Creates a [ScriptRunner].
  ScriptRunner({
    required this.executor,
    required this.console,
    this.dryRun = false,
    FileSystem fs = const SystemFileSystem(),
    Map<String, String>? processEnvironment,
  })  : _fs = fs,
        _processEnvironment = processEnvironment ?? io.Platform.environment;

  /// Runs [events] in order and stops at the first command that fails.
  Future<void> run(List<ExecutionEvent> events) async {
    for (final event in events) {
      switch (event) {
        case CommandExecuted():
          await _execute(event);
        case CommandReferenced():
          _header(event.context, isHook: event.isHook, directory: null);
          console.writeln('${boldGreen(r'$ rps')} ${bold(event.command)}\n');
      }
    }
  }

  void _header(
    Context context, {
    required bool isHook,
    required String? directory,
  }) {
    final basePath = context.basePath;
    if (isHook) {
      basePath.last = blue(basePath.last.substring(1));
    }
    console.writeln([
      boldGreen('>'),
      ...basePath,
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
