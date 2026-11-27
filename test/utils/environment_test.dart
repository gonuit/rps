import 'package:rps/src/utils/environment.dart';
import 'package:test/test.dart';

class FakeEnvironment implements Environment {
  final bool _isCI;
  const FakeEnvironment({required bool isCI}) : _isCI = isCI;

  @override
  bool get isCI => _isCI;

  @override
  bool get hasTerminal => true;

  @override
  bool get stdoutHasTerminal => true;

  @override
  bool get stderrHasTerminal => true;

  @override
  bool get noColor => false;

  @override
  bool get updateCheckDisabled => false;
}

void main() {
  group('Environment', () {
    test('FakeEnvironment returns configured value', () {
      expect(const FakeEnvironment(isCI: true).isCI, isTrue);
      expect(const FakeEnvironment(isCI: false).isCI, isFalse);
    });

    test('isCIValue treats set values as CI', () {
      expect(SystemEnvironment.isCIValue('true'), isTrue);
      expect(SystemEnvironment.isCIValue('1'), isTrue);
      expect(SystemEnvironment.isCIValue('woodpecker'), isTrue);
    });

    test('isCIValue treats missing, empty and falsy values as not CI', () {
      expect(SystemEnvironment.isCIValue(null), isFalse);
      expect(SystemEnvironment.isCIValue(''), isFalse);
      expect(SystemEnvironment.isCIValue('false'), isFalse);
      expect(SystemEnvironment.isCIValue('FALSE'), isFalse);
      expect(SystemEnvironment.isCIValue('0'), isFalse);
    });

    test('isNoColorValue treats any non-empty value as set', () {
      expect(SystemEnvironment.isNoColorValue('1'), isTrue);
      expect(SystemEnvironment.isNoColorValue('false'), isTrue);
      expect(SystemEnvironment.isNoColorValue(''), isFalse);
      expect(SystemEnvironment.isNoColorValue(null), isFalse);
    });

    test('SystemEnvironment can be constructed', () {
      const env = SystemEnvironment();
      expect(env.isCI, isA<bool>());
    });
  });
}
