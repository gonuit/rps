import 'package:rps/src/cli/cli_options/cli_option.dart';
import 'package:rps/rps.dart';
import 'package:rps/src/cli/cli.dart';
import 'package:test/test.dart';

class _TestOption extends CliOption {
  @override
  String get description => 'test';
  @override
  String get name => 'test';
  @override
  String? get short => 't';
  @override
  Future<void> run(Cli cli, Console console, List<String> arguments) async {}
}

class _NoShortOption extends CliOption {
  @override
  String get description => 'long-only';
  @override
  String get name => 'long-only';
  @override
  String? get short => null;
  @override
  Future<void> run(Cli cli, Console console, List<String> arguments) async {}
}

void main() {
  group('CliOption.match', () {
    final option = _TestOption();

    test('matches long form', () {
      expect(option.match(['--test']), isTrue);
    });

    test('matches short form', () {
      expect(option.match(['-t']), isTrue);
    });

    test('does not match unrelated', () {
      expect(option.match(['--other']), isFalse);
    });

    test('does not match empty args', () {
      expect(option.match([]), isFalse);
    });

    test('trims whitespace', () {
      expect(option.match(['  --test  ']), isTrue);
    });

    test('no short option only matches long form', () {
      final option = _NoShortOption();
      expect(option.match(['--long-only']), isTrue);
      expect(option.match(['-l']), isFalse);
    });
  });
}
