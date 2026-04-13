import 'dart:io';

import 'package:rps/rps.dart';
import 'package:rps/src/cli/cli_runner.dart';
import 'package:rps/src/update_check/clock.dart';
import 'package:rps/src/utils/environment.dart';
import 'package:rps/src/utils/file_system.dart';
import 'package:rps/src/utils/platform.dart';

void main(List<String> args) async {
  final exitCode = await runCli(
    args,
    console: Console(sink: stdout),
    errorSink: stderr,
    environment: const SystemEnvironment(),
    platform: const SystemPlatform(),
    fs: const SystemFileSystem(),
    clock: const SystemClock(),
  );
  if (exitCode != 0) exit(exitCode);
}
