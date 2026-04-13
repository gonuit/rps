import 'package:rps/rps.dart';
import 'package:test/test.dart';

void main() {
  group('ScriptParserException', () {
    test('stores message', () {
      final e = ScriptParserException('cycle detected');
      expect(e.message, equals('cycle detected'));
    });
  });
}
