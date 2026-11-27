import 'dart:async';
import 'dart:io' as io;

import 'package:rps/rps.dart';
import 'package:test/test.dart';

void main() {
  group('execute', () {
    final shell = Shell.of(null, const SystemPlatform());

    test('returns 0 for a successful command', () async {
      expect(await execute('exit 0', shell: shell), equals(0));
    });

    test('returns the exit code of the command', () async {
      expect(await execute('exit 7', shell: shell), equals(7));
    });

    test(
      'returns 128 plus the signal for a killed command',
      () async {
        expect(await execute(r'kill -TERM $$', shell: shell), equals(143));
      },
      testOn: '!windows',
    );

    test(
      'uses the given shell',
      () async {
        final code = await execute(
          r'test -n "$ZSH_VERSION"',
          shell: const PosixShell('zsh'),
        );
        expect(code, equals(0));
      },
      testOn: 'mac-os',
    );

    test('adds the given environment', () async {
      final code = await execute(
        io.Platform.isWindows
            ? r'exit $env:RPS_TEST_CODE'
            : r'exit $RPS_TEST_CODE',
        shell: shell,
        environment: {'RPS_TEST_CODE': '5'},
      );
      expect(code, equals(5));
    });

    test('runs in the given working directory', () async {
      final directory = io.Directory.systemTemp.createTempSync('rps_exec_');
      addTearDown(() => directory.deleteSync(recursive: true));
      const command = 'dart --version > output.txt';
      final code = await execute(
        command,
        shell: shell,
        workingDirectory: directory.path,
      );
      expect(code, equals(0));
      expect(io.File('${directory.path}/output.txt').existsSync(), isTrue);
    });

    test('passes the output line by line when asked to', () async {
      final out = <String>[];
      final errors = <String>[];
      final code = await execute(
        io.Platform.isWindows
            ? 'Write-Output one; Write-Output two; '
                '[Console]::Error.WriteLine("oops"); exit 2'
            : 'echo one; echo two; echo oops >&2; exit 2',
        shell: shell,
        output: CommandOutput(onOutput: out.add, onError: errors.add),
      );

      expect(code, equals(2));
      expect(out, equals(['one', 'two']));
      expect(errors, equals(['oops']));
    });

    test('stops the command when it is cancelled', () async {
      final cancel = Completer<void>();
      final out = <String>[];
      final watch = Stopwatch()..start();
      final code = execute(
        io.Platform.isWindows
            ? 'Write-Output started; Start-Sleep 60; Write-Output late'
            : 'echo started; sleep 60; echo late',
        shell: shell,
        output: CommandOutput(
          onOutput: (line) {
            out.add(line);
            if (!cancel.isCompleted) cancel.complete();
          },
          onError: (_) {},
          cancelled: cancel.future,
        ),
      );

      expect(await code, isNot(0));
      expect(out, equals(['started']));
      expect(watch.elapsed, lessThan(const Duration(seconds: 30)));
    });

    test('fails when the interpreter cannot be started', () {
      expect(
        () => execute(
          'exit 0',
          shell: const PosixShell('rps-no-such-interpreter'),
        ),
        throwsA(isA<RpsException>().having(
          (e) => e.message,
          'message',
          contains('Cannot start the "rps-no-such-interpreter" interpreter'),
        )),
      );
    });
  });
}
