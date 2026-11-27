import 'package:rps/rps.dart';
import 'package:test/test.dart';

void main() {
  group('RpsException', () {
    test('stores message', () {
      final e = RpsException('test error');
      expect(e.message, equals('test error'));
    });

    test('stores optional error and stack trace', () {
      final inner = Exception('inner');
      final st = StackTrace.current;
      final e = RpsException('msg', inner, st);
      expect(e.error, equals(inner));
      expect(e.stackTrace, equals(st));
    });

    test('toString includes message', () {
      final e = RpsException('something failed');
      expect(e.toString(), equals('RpsException: something failed'));
    });
  });

  group('exit codes', () {
    test('RpsException exits with 1', () {
      expect(RpsException('x').exitCode, equals(1));
    });

    test('RpsUsageException exits with 64', () {
      final e = RpsUsageException('x');
      expect(e, isA<RpsException>());
      expect(e.exitCode, equals(64));
    });

    test('ScriptFailedException exits with the code of the script', () {
      final e = ScriptFailedException('x', exitCode: 7);
      expect(e, isA<RpsException>());
      expect(e.exitCode, equals(7));
    });

    test('RpsConfigException exits with 78', () {
      final e = RpsConfigException('x');
      expect(e, isA<RpsException>());
      expect(e.exitCode, equals(78));
    });
  });
}
