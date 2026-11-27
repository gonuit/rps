import 'dart:async';
import 'dart:io';

import 'package:rps/rps.dart';
import 'package:rps/src/cli/cli_runner.dart';
import 'package:rps/src/update_check/clock.dart';
import 'package:rps/src/utils/environment.dart';
import 'package:rps/src/utils/file_system.dart';
import 'package:rps/src/utils/platform.dart';

void main(List<String> args) {
  runZonedGuarded(
    () async {
      final exitCode = await runCli(
        args,
        console: Console(sink: stdout),
        errorSink: stderr,
        environment: const SystemEnvironment(),
        platform: const SystemPlatform(),
        fs: const SystemFileSystem(),
        clock: const SystemClock(),
      );
      await stdout.flush();
      await stderr.flush();
      exit(exitCode);
    },
    (error, stackTrace) {
      // The reader of the output is gone, for example in `rps ls | head -1`.
      if (error is FileSystemException) exit(141);
      Error.throwWithStackTrace(error, stackTrace);
    },
  );
}
