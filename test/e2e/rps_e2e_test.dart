import 'dart:convert';
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

String _forwardSlashes(String path) => path.replaceAll(r'\', '/');

Future<ProcessResult> _runIn(
  String yaml,
  List<String> args, {
  String? rpsYaml,
  Map<String, String> files = const {},
  Map<String, String> environment = const {},
  void Function(Directory directory)? verify,
}) async {
  final directory = Directory.systemTemp.createTempSync('rps_e2e_');
  try {
    File('${directory.path}/pubspec.yaml').writeAsStringSync(yaml);
    if (rpsYaml != null) {
      File('${directory.path}/rps.yaml').writeAsStringSync(rpsYaml);
    }
    for (final MapEntry(key: path, value: content) in files.entries) {
      File('${directory.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }
    final result = await Process.run(
      Platform.resolvedExecutable,
      ['${Directory.current.path}/bin/rps.dart', ...args],
      workingDirectory: directory.path,
      environment: {'CI': 'true', ...environment},
    );
    verify?.call(directory);
    return result;
  } finally {
    directory.deleteSync(recursive: true);
  }
}

void main() {
  group('E2E (process)', () {
    sharedE2eTests(_runProcess);

    group('script keys', () {
      test(r'$parallel labels the output and stops at a failure', () async {
        const sleeper = "import 'dart:io';\n"
            'void main() {\n'
            "  stdout.writeln('sleeping');\n"
            '  sleep(const Duration(seconds: 60));\n'
            '}\n';
        final passed = await _runIn(
          'name: app\nscripts:\n'
          '  version: dart --version\n'
          '  all:\n'
          '    \$parallel:\n'
          '      - rps version\n'
          '      - dart --version\n',
          ['all'],
        );
        final watch = Stopwatch()..start();
        final failed = await _runIn(
          'name: app\nscripts:\n'
          '  all:\n'
          '    \$parallel:\n'
          '      - dart sleeper.dart\n'
          '      - exit 4\n',
          ['all'],
          files: {'sleeper.dart': sleeper},
        );

        expect(passed.exitCode, equals(0), reason: '${passed.stderr}');
        expect(passed.stdout, contains('[version] Dart SDK version'));
        expect(passed.stdout, contains('[2      ] Dart SDK version'));
        expect(failed.exitCode, equals(4));
        expect(failed.stderr, contains('The command "2" ended'));
        expect(watch.elapsed, lessThan(const Duration(seconds: 45)));
      });

      test(r'$confirm needs --yes without a terminal', () async {
        const yaml = 'name: app\nscripts:\n'
            '  reset:\n'
            '    \$confirm: Drop the database?\n'
            '    \$script: dart --version\n';
        final refused = await _runIn(yaml, ['reset']);
        final flag = await _runIn(yaml, ['--yes', 'reset']);
        final variable = await _runIn(
          yaml,
          ['reset'],
          environment: {'RPS_YES': '1'},
        );
        final dryRun = await _runIn(yaml, ['--dry-run', 'reset']);

        expect(refused.exitCode, equals(64));
        expect(refused.stderr, contains('Drop the database?'));
        expect(refused.stderr, contains('rps --yes'));
        expect(refused.stdout, isNot(contains('dart --version')));
        expect(flag.exitCode, equals(0), reason: '${flag.stderr}');
        expect(variable.exitCode, equals(0), reason: '${variable.stderr}');
        expect(dryRun.exitCode, equals(0));
        expect(dryRun.stdout, contains('? Drop the database?'));
      });

      test(r'$steps stop at the first step that fails', () async {
        final result = await _runIn(
          'name: app\nscripts:\n'
          '  version: dart --version\n'
          '  check:\n'
          '    \$steps:\n'
          '      - rps version\n'
          '      - exit 3\n'
          '      - dart --version > never.txt\n',
          ['check'],
          verify: (directory) {
            expect(File('${directory.path}/never.txt').existsSync(), isFalse);
          },
        );
        final extra = await _runIn(
          'name: app\nscripts:\n  check:\n    \$steps: [dart --version]\n',
          ['check', 'more'],
        );

        expect(result.exitCode, equals(3));
        expect(result.stdout, contains('> check [2/3]'));
        expect(result.stdout, isNot(contains('[3/3]')));
        expect(extra.exitCode, equals(64));
      });

      test(r'$cwd runs the script in the directory', () async {
        final result = await _runIn(
          'name: app\nscripts:\n'
          '  version:\n'
          '    \$cwd: packages/app\n'
          '    \$script: dart --version > out.txt\n',
          ['version'],
          files: {'packages/app/keep.txt': ''},
          verify: (directory) {
            expect(
              File('${directory.path}/packages/app/out.txt').existsSync(),
              isTrue,
            );
          },
        );
        final missing = await _runIn(
          'name: app\nscripts:\n'
          '  version:\n'
          '    \$cwd: nope\n'
          '    \$script: dart --version\n',
          ['version'],
        );

        expect(result.exitCode, equals(0), reason: '${result.stderr}');
        expect(missing.exitCode, equals(78));
        expect(missing.stderr, contains('does not exist'));
      });
    });

    group('workspace', () {
      const where = "import 'dart:io';\n"
          'void main(List<String> args) {\n'
          '  final env = Platform.environment;\n'
          '  final name = Directory.current.uri.pathSegments.reversed.skip(1).first;\n'
          "  stdout.writeln('<\$name|\${env['WHO']}|\${args.join(',')}>');\n"
          '  if (args.contains(name)) exit(5);\n'
          '}\n';
      const root = 'name: root\nworkspace:\n  - packages/*\n'
          'scripts:\n  where: dart where.dart\n';
      const files = {
        'packages/app/pubspec.yaml': 'name: app\ndependencies:\n  core: any\n'
            'scripts:\n  where: dart where.dart\n',
        'packages/app/where.dart': where,
        'packages/core/pubspec.yaml': 'name: core\n',
        'packages/core/rps.yaml': 'scripts:\n  \$envFile: .env\n'
            '  where: dart where.dart\n',
        'packages/core/.env': 'WHO=core-env',
        'packages/core/where.dart': where,
        'packages/docs/pubspec.yaml': 'name: docs\n',
      };

      test('--all runs the script in each package, dependencies first',
          () async {
        final result =
            await _runIn(root, ['--all', 'where', 'x'], files: files);
        final output = result.stdout as String;

        expect(result.exitCode, equals(0), reason: '${result.stderr}');
        expect(output, contains('<core|core-env|x>'));
        expect(output, contains('<app|null|x>'));
        expect(output.indexOf('<core|'), lessThan(output.indexOf('<app|')));
        expect(output, contains('Ran "where x" in 2 package(s).'));
      });

      test('--all stops at a failed package unless --continue is given',
          () async {
        final stopped =
            await _runIn(root, ['-a', 'where', 'core'], files: files);
        final continued = await _runIn(
          root,
          ['-a', '--continue', 'where', 'core'],
          files: files,
        );

        expect(stopped.exitCode, equals(5));
        expect(stopped.stdout, isNot(contains('<app|')));
        expect(
            stopped.stderr, contains('1 of 2 package(s): core. Not run: app.'));
        expect(continued.exitCode, equals(5));
        expect(continued.stdout, contains('<app|null|core>'));
      });

      test('--all --parallel labels the output with the package', () async {
        final result = await _runIn(
          root,
          ['--all', '--parallel', 'where'],
          files: files,
        );

        expect(result.exitCode, equals(0), reason: '${result.stderr}');
        expect(result.stdout, contains('[core] <core|core-env|>'));
        expect(result.stdout, contains('[app ] <app|null|>'));
      });

      test(
          '--all fails with 64 when no package has the script and with 78 '
          'outside of a workspace', () async {
        final missing = await _runIn(root, ['--all', 'nope'], files: files);
        final outside = await _runIn('name: app\n', ['--all', 'where']);

        expect(missing.exitCode, equals(64));
        expect(outside.exitCode, equals(78));
      });
    });

    group('environment', () {
      const printEnv = "import 'dart:io';\n"
          'void main() {\n'
          '  final env = Platform.environment;\n'
          "  stdout.write('<\${env['A']}|\${env['B']}|\${env['C']}>');\n"
          '}\n';
      const yaml = 'name: app\nscripts:\n'
          '  \$envFile: .env\n'
          '  \$env: {A: key}\n'
          '  show: dart print_env.dart\n';

      test(r'$env and $envFile reach the script', () async {
        final result = await _runIn(
          yaml,
          ['show'],
          files: {'print_env.dart': printEnv, '.env': 'A=file\nB=file\nC=file'},
          environment: {'C': 'process'},
        );

        expect(result.stdout, contains('<key|file|process>'));
        expect(result.exitCode, equals(0));
      });

      test('a missing env file exits with 78', () async {
        final result = await _runIn(
          yaml,
          ['show'],
          files: {'print_env.dart': printEnv},
        );

        expect(result.exitCode, equals(78));
        expect(result.stderr, contains('The env file ".env" does not exist.'));
      });
    });

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

      test('the removed cmd interpreter exits with 78', () async {
        final result = await _runIn(
          'name: app\n',
          ['hello'],
          rpsYaml: 'windows:\n  interpreter: cmd\n'
              'scripts:\n  hello: echo hello\n',
        );

        expect(result.exitCode, equals(78));
        expect(result.stderr, contains('no longer supported'));
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

    group('script process', () {
      const arguments = [
        'plain',
        'two words',
        "it's",
        'say "hi"',
        '',
        'a&b',
        r'$HOME',
        '*',
        'semi;colon',
      ];
      final printArgs = '${_forwardSlashes(Platform.resolvedExecutable)} '
          '${_forwardSlashes(Directory.current.path)}'
          '/test/fixtures/print_args.dart';

      test('passes arguments to the script literally', () async {
        final result = await _runIn(
          'name: app\nscripts:\n  args: $printArgs\n',
          ['args', ...arguments],
        );

        expect(result.exitCode, equals(0), reason: '${result.stderr}');
        expect(
          jsonDecode((result.stdout as String).trim().split('\n').last),
          equals(arguments),
        );
      });

      test('named arguments are filled and quoted', () async {
        final yaml = 'name: app\nscripts:\n'
            '  args:\n'
            '    \$args:\n'
            '      name:\n'
            '      greeting: hello\n'
            '    \$script: $printArgs \${greeting} \${name}\n';
        final result = await _runIn(
          yaml,
          ['args', '--name', "it's a b", 'tail', '--', '--name'],
        );
        final missing = await _runIn(yaml, ['args']);

        expect(result.exitCode, equals(0), reason: '${result.stderr}');
        expect(
          jsonDecode((result.stdout as String).trim().split('\n').last),
          equals(['hello', "it's a b", 'tail', '--name']),
        );
        expect(missing.exitCode, equals(64));
        expect(missing.stderr, contains('requires the argument(s): --name.'));
      });

      test(
        'the script reads piped stdin',
        () async {
          final directory = Directory.systemTemp.createTempSync('rps_e2e_');
          addTearDown(() => directory.deleteSync(recursive: true));
          File('${directory.path}/pubspec.yaml')
              .writeAsStringSync('name: app\nscripts:\n  cat: cat\n');
          final process = await Process.start(
            Platform.resolvedExecutable,
            ['${Directory.current.path}/bin/rps.dart', 'cat'],
            workingDirectory: directory.path,
            environment: {'CI': 'true'},
          );
          process.stdin.writeln('piped-data');
          await process.stdin.close();
          final output = await process.stdout.transform(utf8.decoder).join();

          expect(await process.exitCode, equals(0));
          expect(output.trim().split('\n').last, equals('piped-data'));
        },
        testOn: '!windows',
      );

      test(
        'a script killed by a signal exits with 128 plus the signal',
        () async {
          final result = await _runIn(
            'name: app\nscripts:\n  die: kill -TERM \$\$\n',
            ['die'],
          );

          expect(result.exitCode, equals(143));
        },
        testOn: '!windows',
      );
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
