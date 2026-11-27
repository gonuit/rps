import 'package:rps/rps.dart';
import 'package:rps/src/utils/platform.dart';
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

    test('prints the interpreter in verbose mode', () async {
      final out = StringBuffer();
      await execute('exit 0', shell: shell, verbose: true, out: out);
      expect(out.toString(), startsWith('Using interpreter: '));
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
