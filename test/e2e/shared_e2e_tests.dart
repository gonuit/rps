import 'dart:io' as io;

import 'package:test/test.dart';

/// Result from running rps, abstracted over process vs in-process.
class RpsResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  RpsResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
}

String stripAnsi(String text) {
  return text.replaceAll(RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), '');
}

typedef RpsRunner = Future<RpsResult> Function(
  List<String> args, {
  bool ci,
});

void sharedE2eTests(RpsRunner run) {
  group('CLI options', () {
    test('--help shows usage info', () async {
      final result = await run(['--help']);
      final output = stripAnsi(result.stdout);

      expect(result.exitCode, equals(0));
      expect(output, contains('Run Pubspec Script'));
      expect(output, contains('Options'));
      expect(output, contains('--help'));
      expect(output, contains('--version'));
      expect(output, contains('--upgrade'));
      expect(output, contains('Commands'));
    });

    test('-h is a shorthand for --help', () async {
      final result = await run(['-h']);

      expect(result.exitCode, equals(0));
      expect(stripAnsi(result.stdout), contains('Run Pubspec Script'));
    });

    test('--version prints version', () async {
      final result = await run(['--version']);

      expect(result.exitCode, equals(0));
      expect(stripAnsi(result.stdout), contains('rps version:'));
    });
  });

  group('ls command', () {
    test('lists all available scripts with descriptions', () async {
      final result = await run(['ls']);
      final output = stripAnsi(result.stdout);

      expect(result.exitCode, equals(0));
      expect(output, contains('Commands'));
      expect(output, contains('run'));
      expect(output, contains('gen'));
      expect(output, contains('target'));
      expect(output, contains('get'));
      expect(output, contains('test'));
      expect(output, contains('build android apk'));
      expect(output, contains('build android appbundle'));
      expect(output, contains('bab'));
      expect(output, contains('baa'));
      expect(output, contains('clear'));
      expect(output, contains('reset'));
    });

    test('shows descriptions', () async {
      final result = await run(['ls']);
      final output = stripAnsi(result.stdout);

      expect(output, contains('Runs the app in development mode'));
      expect(output, contains('Generates code with build_runner'));
      expect(output, contains('Builds production Android APK'));
      expect(output, contains('Clears the app cache'));
    });
  });

  group('run command', () {
    test('executes a simple script', () async {
      final result = await run(['gen']);
      final output = stripAnsi(result.stdout);

      expect(result.exitCode, equals(0));
      expect(output, contains('> gen'));
      expect(output, contains('flutter pub run build_runner'));
    });

    test('executes a \$script-based command', () async {
      final result = await run(['run']);
      final output = stripAnsi(result.stdout);

      expect(result.exitCode, equals(0));
      expect(output, contains('> run'));
      expect(output, contains('flutter run'));
    });

    test('nonexistent script fails with exit code 1', () async {
      final result = await run(['nonexistent']);

      expect(result.exitCode, equals(1));
      expect(stripAnsi(result.stderr), contains('Error!'));
    });
  });

  group('nesting', () {
    test('executes deeply nested script', () async {
      final result = await run(['build', 'android', 'apk']);
      final output = stripAnsi(result.stdout);

      expect(result.exitCode, equals(0));
      expect(output, contains('> build android apk'));
      expect(output, contains('flutter build --release apk'));
    });

    test('executes another nested path', () async {
      final result = await run(['build', 'android', 'appbundle']);

      expect(result.exitCode, equals(0));
      expect(
        stripAnsi(result.stdout),
        contains('flutter build --release appbundle'),
      );
    });

    test('incomplete nested path fails', () async {
      final result = await run(['build', 'android']);

      expect(result.exitCode, equals(1));
      expect(stripAnsi(result.stderr), contains('Error!'));
    });
  });

  group('hooks', () {
    test('\$before hook runs before main script', () async {
      final result = await run(['build', 'android', 'apk']);
      final output = stripAnsi(result.stdout);

      expect(result.exitCode, equals(0));
      expect(output, contains('flutter pub get'));
      expect(output, contains('Building android apk...'));
      expect(output, contains('flutter build --release apk'));
    });

    test('\$after hook runs after main script', () async {
      final result = await run(['build', 'android', 'appbundle']);
      final output = stripAnsi(result.stdout);

      expect(result.exitCode, equals(0));
      expect(output, contains('flutter build --release appbundle'));
      expect(output, contains('Build done!'));
    });

    test('hooks from parent and child both execute in order', () async {
      final result = await run(['build', 'android', 'apk']);
      final output = stripAnsi(result.stdout);

      final pubGetIndex = output.indexOf('flutter pub get');
      final buildingIndex = output.indexOf('Building android apk');
      final buildIndex = output.indexOf('flutter build --release apk');
      final doneIndex = output.indexOf('Build done!');

      expect(pubGetIndex, lessThan(buildingIndex));
      expect(buildingIndex, lessThan(buildIndex));
      expect(buildIndex, lessThan(doneIndex));
    });
  });

  group('references', () {
    test('rps reference resolves to target script', () async {
      final result = await run(['bab']);
      final output = stripAnsi(result.stdout);

      expect(result.exitCode, equals(0));
      expect(output, contains('rps build android appbundle'));
      expect(output, contains('flutter build --release appbundle'));
    });

    test('another rps reference works', () async {
      final result = await run(['baa']);
      final output = stripAnsi(result.stdout);

      expect(result.exitCode, equals(0));
      expect(output, contains('rps build android apk'));
      expect(output, contains('flutter build --release apk'));
    });

    test('reference in \$before hook resolves', () async {
      final result = await run(['test']);
      final output = stripAnsi(result.stdout);

      expect(result.exitCode, equals(0));
      expect(output, contains('rps get'));
      expect(output, contains('flutter pub get'));
      expect(output, contains('flutter test'));
    });
  });

  group('positional arguments', () {
    test('fills positional arg placeholders', () async {
      final result = await run(['target', 'apk']);

      expect(result.exitCode, equals(0));
      expect(
        stripAnsi(result.stdout),
        contains('flutter build apk -t lib/main.dart'),
      );
    });

    test('different positional arg value', () async {
      final result = await run(['target', 'appbundle']);

      expect(result.exitCode, equals(0));
      expect(
        stripAnsi(result.stdout),
        contains('flutter build appbundle -t lib/main.dart'),
      );
    });
  });

  group('platform-specific scripts', () {
    test('clear runs platform-appropriate command', () async {
      final result = await run(['clear']);
      final output = stripAnsi(result.stdout);

      expect(result.exitCode, equals(0));
      if (io.Platform.isMacOS) {
        expect(output, contains('rm -rf ~/Library/Caches/app'));
      } else if (io.Platform.isLinux) {
        expect(output, contains('rm -rf /var/cache/app'));
      } else if (io.Platform.isWindows) {
        expect(output, contains(r'rd /s /q app\cache'));
      }
    });
  });

  group('multiline scripts', () {
    test('reset runs multiline script', () async {
      final result = await run(['reset']);
      final output = stripAnsi(result.stdout);

      expect(result.exitCode, equals(0));
      expect(output, contains('flutter clean'));
      expect(output, contains('flutter pub get'));
    });
  });

  group('additional arguments', () {
    test('passes extra args to script', () async {
      final result = await run(['get', '--verbose']);

      expect(result.exitCode, equals(0));
      final output = stripAnsi(result.stdout);
      // The compiled command includes the extra args
      expect(output, contains('flutter pub get'));
      expect(output, contains('--verbose'));
    });
  });

  group('CI mode', () {
    test('no args fails with exit code 1', () async {
      final result = await run([], ci: true);

      expect(result.exitCode, equals(1));
      expect(
        stripAnsi(result.stderr),
        contains('No command has been matched'),
      );
    });

    test('with args runs normally', () async {
      final result = await run(['gen'], ci: true);

      expect(result.exitCode, equals(0));
      expect(stripAnsi(result.stdout), contains('> gen'));
    });

    test('--help still works', () async {
      final result = await run(['--help'], ci: true);

      expect(result.exitCode, equals(0));
      expect(stripAnsi(result.stdout), contains('Run Pubspec Script'));
    });

    test('ls still works', () async {
      final result = await run(['ls'], ci: true);

      expect(result.exitCode, equals(0));
      expect(stripAnsi(result.stdout), contains('Commands'));
    });

    test('hooks work in CI', () async {
      final result = await run(['build', 'android', 'apk'], ci: true);
      final output = stripAnsi(result.stdout);

      expect(result.exitCode, equals(0));
      expect(output, contains('flutter pub get'));
      expect(output, contains('flutter build --release apk'));
      expect(output, contains('Build done!'));
    });

    test('references work in CI', () async {
      final result = await run(['bab'], ci: true);

      expect(result.exitCode, equals(0));
      expect(
        stripAnsi(result.stdout),
        contains('flutter build --release appbundle'),
      );
    });
  });
}
