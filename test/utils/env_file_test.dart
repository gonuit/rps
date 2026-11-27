import 'package:rps/rps.dart';
import 'package:rps/src/utils/env_file.dart';
import 'package:test/test.dart';

void main() {
  group('parseEnvFile', () {
    test('reads names and values', () {
      final variables = parseEnvFile(
        'A=1\n'
        'B = two words \r\n'
        '\n'
        '# comment\n'
        'export C=3\n'
        'EMPTY=\n'
        'URL=https://example.com/?a=b#c\n',
        path: '.env',
      );

      expect(variables, {
        'A': '1',
        'B': 'two words',
        'C': '3',
        'EMPTY': '',
        'URL': 'https://example.com/?a=b#c',
      });
    });

    test('reads quoted values and inline comments', () {
      final variables = parseEnvFile(
        'DOUBLE="a # b\\n\\"c\\""\n'
        "SINGLE='a # \\n b'\n"
        'PLAIN=value # comment\n',
        path: '.env',
      );

      expect(variables, {
        'DOUBLE': 'a # b\n"c"',
        'SINGLE': r'a # \n b',
        'PLAIN': 'value',
      });
    });

    test('lets a later line win', () {
      expect(parseEnvFile('A=1\nA=2', path: '.env'), {'A': '2'});
    });

    test('rejects lines without a name', () {
      for (final content in ['A=1\nnonsense', '=value', 'A B=1']) {
        expect(
          () => parseEnvFile(content, path: 'config/.env'),
          throwsA(isA<RpsConfigException>().having(
            (e) => e.message,
            'message',
            allOf(contains('config/.env'), contains('Expected NAME=VALUE')),
          )),
        );
      }
    });
  });
}
