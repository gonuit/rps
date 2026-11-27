import 'package:rps/rps.dart';
import 'package:rps/src/models/interpreter.dart';
import 'package:rps/src/utils/platform.dart';
import 'package:test/test.dart';

import '../mocks/fake_platform.dart';

class _MissingInterpreter implements Interpreter {
  @override
  String get value => 'rps-no-such-interpreter';
}

void main() {
  group('execute', () {
    const platform = SystemPlatform();

    test('returns 0 for a successful command', () async {
      expect(await execute('exit 0', platform: platform), equals(0));
    });

    test('returns the exit code of the command', () async {
      expect(await execute('exit 7', platform: platform), equals(7));
    });

    test(
      'returns 128 plus the signal for a killed command',
      () async {
        expect(
            await execute(r'kill -TERM $$', platform: platform), equals(143));
      },
      testOn: '!windows',
    );

    test(
      'uses the given interpreter',
      () async {
        final code = await execute(
          r'test -n "$ZSH_VERSION"',
          interpreter: UnixInterpreter.zsh,
          platform: platform,
        );
        expect(code, equals(0));
      },
      testOn: 'mac-os',
    );

    test('prints the interpreter in verbose mode', () async {
      final out = StringBuffer();
      await execute('exit 0', platform: platform, verbose: true, out: out);
      expect(out.toString(), startsWith('Using interpreter: '));
    });

    test('fails when the interpreter cannot be started', () {
      expect(
        () => execute(
          'exit 0',
          interpreter: _MissingInterpreter(),
          platform: platform,
        ),
        throwsA(isA<RpsException>().having(
          (e) => e.message,
          'message',
          contains('Cannot start the "rps-no-such-interpreter" interpreter'),
        )),
      );
    });

    test('rejects a Windows interpreter on other platforms', () {
      expect(
        () => execute(
          'exit 0',
          interpreter: WindowsInterpreter.cmd,
          platform: const FakePlatform.linux(),
        ),
        throwsA(isA<RpsException>()),
      );
    });

    test('rejects a Unix interpreter on Windows', () {
      expect(
        () => execute(
          'exit 0',
          interpreter: UnixInterpreter.bash,
          platform: const FakePlatform.windows(),
        ),
        throwsA(isA<RpsException>()),
      );
    });
  });
}
