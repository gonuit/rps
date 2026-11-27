import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:rps/rps.dart';

/// Callback type for functions that execute a shell command.
typedef ExecuteFunction = Future<int> Function(
  String command,
);

/// Receives the output of a command that runs without a terminal.
class CommandOutput {
  /// Called with every line the command writes to stdout.
  final void Function(String line) onOutput;

  /// Called with every line the command writes to stderr.
  final void Function(String line) onError;

  /// Completes when the command should be stopped.
  final Future<void>? cancelled;

  /// Creates a [CommandOutput].
  const CommandOutput({
    required this.onOutput,
    required this.onError,
    this.cancelled,
  });
}

Future<void> _stop(io.Process process) async {
  if (io.Platform.isWindows) {
    try {
      await io.Process.run('taskkill', ['/T', '/F', '/PID', '${process.pid}']);
    } on io.ProcessException {
      process.kill();
    }
    return;
  }

  // The interpreter is paused so it cannot start anything new meanwhile.
  process.kill(io.ProcessSignal.sigstop);
  try {
    await io.Process.run('pkill', ['-TERM', '-P', '${process.pid}']);
  } on io.ProcessException {
    // Without pkill only the interpreter itself is stopped.
  }
  process.kill(io.ProcessSignal.sigterm);
  process.kill(io.ProcessSignal.sigcont);
}

/// Executes [command] in the [shell] and returns its exit code.
///
/// [environment] is added to the environment of this process. The command
/// uses the terminal of this process, unless [output] is given: then its
/// output is passed there line by line and it gets no input.
Future<int> execute(
  String command, {
  required Shell shell,
  Map<String, String>? environment,
  String? workingDirectory,
  CommandOutput? output,
  bool verbose = false,
  StringSink? out,
}) async {
  if (verbose) {
    out?.writeln('Using interpreter: ${shell.executable}');
  }

  final io.Process process;
  try {
    process = await io.Process.start(
      shell.executable,
      shell.arguments(command),
      environment: environment,
      workingDirectory: workingDirectory,
      mode: output == null
          ? io.ProcessStartMode.inheritStdio
          : io.ProcessStartMode.normal,
    );
  } on io.ProcessException catch (err, st) {
    throw RpsException(
      'Cannot start the "${shell.executable}" interpreter. ${err.message}',
      err,
      st,
    );
  }

  var cancelled = false;
  final lines = <StreamSubscription<String>>[];
  if (output != null) {
    process.stdin.close().ignore();
    for (final (stream, onLine) in [
      (process.stdout, output.onOutput),
      (process.stderr, output.onError),
    ]) {
      lines.add(
        stream
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter())
            .listen(onLine),
      );
    }
    output.cancelled?.then((_) {
      cancelled = true;
      return _stop(process);
    }).ignore();
  }

  final subscriptions = [
    io.ProcessSignal.sigint.watch().listen((_) {}),
    if (!io.Platform.isWindows)
      io.ProcessSignal.sigterm
          .watch()
          .listen((_) => process.kill(io.ProcessSignal.sigterm)),
  ];
  try {
    final exitCode = await process.exitCode;
    if (!cancelled) {
      await Future.wait(lines.map((line) => line.asFuture<void>()))
          .timeout(const Duration(seconds: 1), onTimeout: () => const []);
    }
    return exitCode < 0 ? 128 - exitCode : exitCode;
  } finally {
    for (final subscription in [...subscriptions, ...lines]) {
      await subscription.cancel();
    }
  }
}
