import 'package:rps/src/cli/global_flags.dart';
import 'package:test/test.dart';

void main() {
  group('GlobalFlags.parse', () {
    test('leaves arguments without flags untouched', () {
      final flags = GlobalFlags.parse(['build', 'apk']);
      expect(flags.noColor, isFalse);
      expect(flags.arguments, equals(['build', 'apk']));
    });

    test('reads a flag before the script name', () {
      final flags = GlobalFlags.parse(['--no-color', 'build', 'apk']);
      expect(flags.noColor, isTrue);
      expect(flags.arguments, equals(['build', 'apk']));
    });

    test('reads a flag after run and ls', () {
      final run = GlobalFlags.parse(['run', '--no-color', 'build']);
      expect(run.noColor, isTrue);
      expect(run.arguments, equals(['run', 'build']));

      final ls = GlobalFlags.parse(['ls', '--no-color']);
      expect(ls.noColor, isTrue);
      expect(ls.arguments, equals(['ls']));
    });

    test('leaves flags after the script name to the script', () {
      final flags = GlobalFlags.parse(['build', '--no-color']);
      expect(flags.noColor, isFalse);
      expect(flags.arguments, equals(['build', '--no-color']));
    });

    test('treats only the first run as the command name', () {
      final flags = GlobalFlags.parse(['run', 'run', '--no-color']);
      expect(flags.noColor, isFalse);
      expect(flags.arguments, equals(['run', 'run', '--no-color']));
    });

    test('handles empty arguments', () {
      final flags = GlobalFlags.parse([]);
      expect(flags.noColor, isFalse);
      expect(flags.arguments, isEmpty);
    });
  });
}
