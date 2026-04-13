import 'package:rps/src/utils/environment.dart';
import 'package:test/test.dart';

class FakeEnvironment implements Environment {
  final bool _isCI;
  const FakeEnvironment({required bool isCI}) : _isCI = isCI;

  @override
  bool get isCI => _isCI;
}

void main() {
  group('Environment', () {
    test('FakeEnvironment returns configured value', () {
      expect(const FakeEnvironment(isCI: true).isCI, isTrue);
      expect(const FakeEnvironment(isCI: false).isCI, isFalse);
    });

    test('SystemEnvironment can be constructed', () {
      const env = SystemEnvironment();
      expect(env.isCI, isA<bool>());
    });
  });
}
