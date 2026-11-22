import 'package:rps/rps.dart';
import 'package:test/test.dart';

void main() {
  group('quoteArgument posix', () {
    String quote(String arg) => quoteArgument(arg, ShellSyntax.posix);

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

  group('quoteArgument powershell', () {
    String quote(String arg) => quoteArgument(arg, ShellSyntax.powershell);

    test('leaves safe arguments untouched', () {
      expect(quote(r'lib\main.dart'), r'lib\main.dart');
    });

    test('quotes empty argument', () {
      expect(quote(''), "''");
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

  group('quoteArgument cmd', () {
    String quote(String arg) => quoteArgument(arg, ShellSyntax.cmd);

    test('leaves safe arguments untouched', () {
      expect(quote('--flavor=prod'), '--flavor=prod');
    });

    test('quotes empty argument', () {
      expect(quote(''), '""');
    });

    test('quotes spaces', () {
      expect(quote('hello world'), '^"hello^ world^"');
    });

    test('escapes metacharacters', () {
      expect(quote('a&b'), 'a^&b');
      expect(quote('100%'), '100^%');
    });

    test('escapes double quotes and trailing backslashes', () {
      expect(quote('he"llo'), r'^"he\^"llo^"');
      expect(quote(r'a b\'), r'^"a^ b\\^"');
    });
  });
}
