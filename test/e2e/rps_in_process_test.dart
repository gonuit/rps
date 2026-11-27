import 'package:rps/rps.dart';
import 'package:rps/src/cli/cli_runner.dart';
import 'package:rps/src/update_check/clock.dart';
import 'package:rps/src/utils/file_system.dart';
import 'package:rps/src/utils/platform.dart';
import 'package:test/test.dart';

import '../mocks/fake_environment.dart';
import '../mocks/fake_executor.dart';
import '../mocks/stream_sink_controller.dart';
import 'shared_e2e_tests.dart';

Future<RpsResult> _runInProcess(List<String> args, {bool ci = false}) async {
  final stdoutSink = StreamSinkController();
  final stderrSink = StreamSinkController();
  final console = Console(sink: stdoutSink);

  final exitCode = await runCli(
    args,
    console: console,
    errorSink: stderrSink,
    environment: FakeEnvironment(isCI: ci),
    platform: const SystemPlatform(),
    fs: const SystemFileSystem(),
    clock: const SystemClock(),
    executor: FakeExecutor(),
  );

  return RpsResult(
    exitCode: exitCode,
    stdout: stdoutSink.lines.join('\n'),
    stderr: stderrSink.lines.join('\n'),
  );
}

void main() {
  group('E2E (in-process)', () {
    sharedE2eTests(_runInProcess);
  });
}
