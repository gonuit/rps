import 'package:rps/rps.dart';
import 'package:rps/src/cli/arguments.dart';
import 'package:test/test.dart';

void main() {
  group('RpsArguments.parse', () {
    test('runs a script with its arguments', () {
      final arguments = RpsArguments.parse(['build', 'apk', '--release']);

      expect(arguments.action, equals(RpsAction.run));
      expect(arguments.script, equals(['build', 'apk', '--release']));
      expect(arguments.dryRun, isFalse);
      expect(arguments.noColor, isFalse);
    });

    test('reads flags before the script name', () {
      final arguments = RpsArguments.parse(['--no-color', '-n', 'build']);

      expect(arguments.action, equals(RpsAction.run));
      expect(arguments.noColor, isTrue);
      expect(arguments.dryRun, isTrue);
      expect(arguments.script, equals(['build']));
    });

    test('leaves flags after the script name to the script', () {
      final arguments = RpsArguments.parse(
        ['build', '--no-color', '--dry-run', '-n', '--help', '--json'],
      );

      expect(arguments.action, equals(RpsAction.run));
      expect(arguments.noColor, isFalse);
      expect(arguments.dryRun, isFalse);
      expect(
        arguments.script,
        equals(['build', '--no-color', '--dry-run', '-n', '--help', '--json']),
      );
    });

    test('keeps the run command name and reads flags after it', () {
      final arguments = RpsArguments.parse(
        ['run', '--dry-run', '--no-color', 'build', '-n'],
      );

      expect(arguments.action, equals(RpsAction.run));
      expect(arguments.dryRun, isTrue);
      expect(arguments.noColor, isTrue);
      expect(arguments.script, equals(['run', 'build', '-n']));
    });

    test('treats only the first run as the command name', () {
      final arguments = RpsArguments.parse(['run', 'run', '--no-color']);

      expect(arguments.noColor, isFalse);
      expect(arguments.script, equals(['run', 'run', '--no-color']));
    });

    test('reads --all before the script name and after run', () {
      expect(RpsArguments.parse(['--all', 'test']).all, isTrue);
      expect(RpsArguments.parse(['-a', 'test', 'x']).script, ['test', 'x']);
      expect(RpsArguments.parse(['run', '--all', 'test']).all, isTrue);
      expect(RpsArguments.parse(['test', '--all']).all, isFalse);
    });

    test('reads --continue and --parallel only with --all', () {
      final arguments = RpsArguments.parse(['--all', '--continue', 'test']);

      expect(arguments.continueOnError, isTrue);
      expect(arguments.script, equals(['test']));
      expect(RpsArguments.parse(['-a', '--parallel', 'test']).parallel, isTrue);
      for (final option in ['--continue', '--parallel']) {
        expect(
          () => RpsArguments.parse([option, 'test']),
          throwsA(isA<RpsUsageException>()),
          reason: option,
        );
      }
    });

    test('rejects --all without a script', () {
      for (final arguments in [
        ['--all'],
        ['--all', 'ls'],
      ]) {
        expect(
          () => RpsArguments.parse(arguments),
          throwsA(isA<RpsUsageException>()),
          reason: '$arguments',
        );
      }
      expect(RpsArguments.parse(['--all', '-h']).action, RpsAction.help);
    });

    test('runs the default script for a bare run', () {
      final arguments = RpsArguments.parse(['run']);

      expect(arguments.action, equals(RpsAction.run));
      expect(arguments.script, equals(['run']));
    });

    test('lists scripts', () {
      final plain = RpsArguments.parse(['ls']);
      final json = RpsArguments.parse(['ls', '--json', '--no-color']);
      final before = RpsArguments.parse(['--no-color', 'ls']);

      expect(plain.action, equals(RpsAction.list));
      expect(plain.json, isFalse);
      expect(json.action, equals(RpsAction.list));
      expect(json.json, isTrue);
      expect(json.noColor, isTrue);
      expect(before.action, equals(RpsAction.list));
      expect(before.noColor, isTrue);
    });

    test('selects a script when there is nothing to run', () {
      expect(RpsArguments.parse([]).action, equals(RpsAction.select));

      final flagsOnly = RpsArguments.parse(['--dry-run', '--no-color']);
      expect(flagsOnly.action, equals(RpsAction.select));
      expect(flagsOnly.dryRun, isTrue);
      expect(flagsOnly.noColor, isTrue);
    });

    test('reads help, version and upgrade', () {
      expect(RpsArguments.parse(['--help']).action, equals(RpsAction.help));
      expect(RpsArguments.parse(['-h']).action, equals(RpsAction.help));
      expect(
        RpsArguments.parse(['--version']).action,
        equals(RpsAction.version),
      );
      expect(
        RpsArguments.parse(['--upgrade']).action,
        equals(RpsAction.upgrade),
      );
      expect(RpsArguments.parse(['-u']).action, equals(RpsAction.upgrade));
      expect(
        RpsArguments.parse(['--no-color', '--help']).action,
        equals(RpsAction.help),
      );
    });

    test('reads the confirmation flag', () {
      expect(RpsArguments.parse(['--yes', 'reset']).yes, isTrue);
      expect(RpsArguments.parse(['-y', 'reset']).yes, isTrue);
      expect(RpsArguments.parse(['run', '-y', 'reset']).yes, isTrue);
      expect(RpsArguments.parse(['reset', '--yes']).yes, isFalse);
      expect(RpsArguments.parse(['reset']).yes, isFalse);
    });

    test('rejects unknown options before the script name', () {
      expect(
        () => RpsArguments.parse(['--unknown', 'build']),
        throwsA(isA<RpsUsageException>()
            .having((e) => e.exitCode, 'exitCode', 64)
            .having((e) => e.hint, 'hint', contains('rps --help'))),
      );
      expect(
        () => RpsArguments.parse(['ls', '--unknown']),
        throwsA(isA<RpsUsageException>()),
      );
    });

    test('describes the options', () {
      expect(RpsArguments.optionsUsage, contains('--help'));
      expect(RpsArguments.optionsUsage, contains('--version'));
      expect(RpsArguments.optionsUsage, contains('--upgrade'));
      expect(RpsArguments.optionsUsage, contains('--dry-run'));
      expect(RpsArguments.optionsUsage, contains('--no-color'));
    });
  });

  group('RpsArguments.disablesColor', () {
    test('finds the flag before the script name', () {
      expect(RpsArguments.disablesColor(['--no-color', 'build']), isTrue);
      expect(RpsArguments.disablesColor(['run', '--no-color', 'x']), isTrue);
      expect(RpsArguments.disablesColor(['ls', '--no-color']), isTrue);
      expect(RpsArguments.disablesColor(['--bad', '--no-color']), isTrue);
    });

    test('ignores the flag after the script name', () {
      expect(RpsArguments.disablesColor(['build', '--no-color']), isFalse);
      expect(RpsArguments.disablesColor([]), isFalse);
      expect(
        RpsArguments.disablesColor(['run', 'run', '--no-color']),
        isFalse,
      );
    });
  });
}
