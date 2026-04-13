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

void main() {
  group('E2E (process)', () {
    sharedE2eTests(_runProcess);
  });
}
