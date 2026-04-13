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
}
