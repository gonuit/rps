import 'dart:async';
import 'dart:io' as io;

import 'package:rps/rps.dart';

/// Callback type for functions that execute a shell command.
typedef ExecuteFunction = Future<int> Function(
  String command,
);

/// Executes [command] in the [shell] and returns its exit code.
///
/// [environment] is added to the environment of this process.
Future<int> execute(
  String command, {
  required Shell shell,
  Map<String, String>? environment,
  String? workingDirectory,
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
      mode: io.ProcessStartMode.inheritStdio,
    );
  } on io.ProcessException catch (err, st) {
    throw RpsException(
      'Cannot start the "${shell.executable}" interpreter. ${err.message}',
      err,
      st,
    );
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
    return exitCode < 0 ? 128 - exitCode : exitCode;
  } finally {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  }
}
