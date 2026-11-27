import 'dart:io';

import 'package:test/test.dart';

import 'shared_e2e_tests.dart';

Future<RpsResult> _runProcess(List<String> args, {bool ci = false}) async {
  final result = await Process.run(
    'dart',
    ['run', 'bin/rps.dart', ...args],
    environment: ci ? {'CI': 'true'} : null,
  );
  return RpsResult(
    exitCode: result.exitCode,
    stdout: result.stdout as String,
    stderr: result.stderr as String,
  );
}

Future<ProcessResult> _runIn(String yaml, List<String> args) async {
  final directory = Directory.systemTemp.createTempSync('rps_e2e_');
  try {
    File('${directory.path}/pubspec.yaml').writeAsStringSync(yaml);
    return await Process.run(
      Platform.resolvedExecutable,
      ['${Directory.current.path}/bin/rps.dart', ...args],
      workingDirectory: directory.path,
      environment: {'CI': 'true'},
    );
  } finally {
    directory.deleteSync(recursive: true);
  }
}

void main() {
  group('E2E (process)', () {
    sharedE2eTests(_runProcess);

    group('exit codes', () {
      test('configuration errors exit with 78', () async {
        final noScripts = await _runIn('name: app\n', ['build']);
        final invalid = await _runIn('name: app\nscripts: [a\n', ['build']);
        final cycle = await _runIn(
          'name: app\nscripts:\n  a: rps b\n  b: rps a\n',
          ['a'],
        );
        final badScript = await _runIn(
          'name: app\nscripts:\n  a: echo \${1}\n',
          ['a'],
        );

        expect(noScripts.exitCode, equals(78));
        expect(invalid.exitCode, equals(78));
        expect(cycle.exitCode, equals(78));
        expect(badScript.exitCode, equals(78));
      });

      test('a missing pubspec exits with 78', () async {
        final directory = Directory.systemTemp.createTempSync('rps_e2e_');
        addTearDown(() => directory.deleteSync(recursive: true));
        final result = await Process.run(
          Platform.resolvedExecutable,
          ['${Directory.current.path}/bin/rps.dart', 'build'],
          workingDirectory: directory.path,
          environment: {'CI': 'true'},
        );

        expect(result.exitCode, equals(78));
      });

      test('the exit code of a script is passed through', () async {
        const yaml = 'name: app\nscripts:\n'
            '  fail: exit 7\n'
            '  hooked:\n'
            '    \$before: exit 3\n'
            '    \$script: echo never\n';
        final failed = await _runIn(yaml, ['fail']);
        final hooked = await _runIn(yaml, ['hooked']);

        expect(failed.exitCode, equals(7));
        expect(hooked.exitCode, equals(3));
        expect(hooked.stdout, isNot(contains('never\n')));
      });
    });

    test('output has no colors without a terminal', () async {
      final listed = await _runProcess(['ls'], ci: true);
      final failed = await _runProcess(['nonexistent'], ci: true);

      expect(listed.stdout, contains('Commands'));
      expect(listed.stdout, isNot(contains('\x1B')));
      expect(failed.stderr, contains('Error!'));
      expect(failed.stderr, isNot(contains('\x1B')));
    });
  });
}
