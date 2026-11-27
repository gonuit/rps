import 'package:rps/rps.dart';
import 'package:rps/src/models/interpreter.dart';
import 'package:test/test.dart';

import '../mocks/fake_platform.dart';

void main() {
  group('PosixShell.quote', () {
    String quote(String arg) => const PosixShell().quote(arg);

    test('leaves safe arguments untouched', () {
      expect(quote('--flavor=prod'), '--flavor=prod');
      expect(quote('lib/main.dart'), 'lib/main.dart');
    });

    test('quotes empty argument', () {
      expect(quote(''), "''");
    });

    test('quotes spaces and metacharacters', () {
      expect(quote('hello world'), "'hello world'");
      expect(quote('a&b'), "'a&b'");
      expect(quote('a;b'), "'a;b'");
      expect(quote(r'$HOME'), r"'$HOME'");
      expect(quote('*'), "'*'");
    });

    test('escapes single quotes', () {
      expect(quote("it's"), r"'it'\''s'");
    });

    test('keeps double quotes and backslashes literal', () {
      expect(quote(r'a"b\c'), r"""'a"b\c'""");
    });
  });

  group('PowerShell.quote', () {
    String quote(String arg) => const PowerShell().quote(arg);

    test('leaves safe arguments untouched', () {
      expect(quote(r'lib\main.dart'), r'lib\main.dart');
    });

    test('passes an empty argument as a pair of double quotes', () {
      expect(quote(''), """'""'""");
    });

    test('quotes spaces and metacharacters', () {
      expect(quote('hello world'), "'hello world'");
      expect(quote('a,b'), "'a,b'");
      expect(quote(r'$env:PATH'), r"'$env:PATH'");
    });

    test('doubles single quotes', () {
      expect(quote("it's"), "'it''s'");
    });

    test('escapes double quotes', () {
      expect(quote('he"llo'), r"""'he\"llo'""");
    });
  });

  group('Shell.of', () {
    test('defaults to bash on Linux and macOS', () {
      final linux = Shell.of(null, const FakePlatform.linux());
      final macos = Shell.of(null, const FakePlatform());

      expect(linux, isA<PosixShell>());
      expect(linux.executable, equals('bash'));
      expect(macos.executable, equals('bash'));
      expect(linux.arguments('echo hi'), equals(['-c', 'echo hi']));
    });

    test('defaults to PowerShell on Windows', () {
      final shell = Shell.of(null, const FakePlatform.windows());

      expect(shell, isA<PowerShell>());
      expect(shell.executable, equals('powershell'));
      expect(shell.arguments('echo hi'), equals(['-Command', 'echo hi']));
    });

    test('uses the configured interpreter', () {
      final zsh = Shell.of(UnixInterpreter.zsh, const FakePlatform());
      final powershell = Shell.of(
        WindowsInterpreter.powershell,
        const FakePlatform.windows(),
      );

      expect(zsh.executable, equals('zsh'));
      expect(powershell, isA<PowerShell>());
    });

    test('rejects a Windows interpreter on other platforms', () {
      expect(
        () => Shell.of(
          WindowsInterpreter.powershell,
          const FakePlatform.linux(),
        ),
        throwsA(isA<RpsException>()),
      );
    });

    test('rejects a Unix interpreter on Windows', () {
      expect(
        () => Shell.of(UnixInterpreter.bash, const FakePlatform.windows()),
        throwsA(isA<RpsException>()),
      );
    });
  });
}
