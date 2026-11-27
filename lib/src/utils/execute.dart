import 'dart:async';
import 'dart:io' as io;

import 'package:rps/rps.dart';
import 'package:rps/src/models/interpreter.dart';
import 'package:rps/src/utils/platform.dart';

/// Callback type for functions that execute a shell command.
typedef ExecuteFunction = Future<int> Function(
  String command,
);

/// Executes a shell [command] and returns its exit code.
Future<int> execute(
  String command, {
  bool verbose = false,
  Interpreter? interpreter,
  StringSink? out,
  required Platform platform,
}) async {
  if (!platform.isWindows && interpreter is WindowsInterpreter) {
    throw RpsException(
      'The Windows interpreter cannot be used on ${platform.operatingSystem}.',
    );
  }
  if (!platform.isLinux &&
      !platform.isMacOS &&
      interpreter is UnixInterpreter) {
    throw RpsException(
      'The Unix interpreter cannot be used on ${platform.operatingSystem}.',
    );
  }

  final executable =
      interpreter?.value ?? (platform.isWindows ? 'powershell' : 'bash');
  final flag = switch (executable) {
    'powershell' => '-Command',
    'cmd' => '/c',
    _ => '-c',
  };

  if (verbose) {
    out?.writeln('Using interpreter: $executable');
  }

  final io.Process process;
  try {
    process = await io.Process.start(
      executable,
      [flag, command],
      mode: io.ProcessStartMode.inheritStdio,
    );
  } on io.ProcessException catch (err, st) {
    throw RpsException(
      'Cannot start the "$executable" interpreter. ${err.message}',
      err,
      st,
    );
  }

  final subscriptions = [
    io.ProcessSignal.sigint.watch().listen((_) {}),
    if (!platform.isWindows)
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
