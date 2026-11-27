import 'package:rps/rps.dart';
import 'package:test/test.dart';

void main() {
  group('ScriptInfo', () {
    test('describes a plain script', () {
      final info = ScriptInfo(
        keys: ['build', 'apk'],
        script: const Script(
          command: 'flutter build\n  apk',
          description: 'Builds the app',
        ),
      );

      expect(info.path, equals('build apk'));
      expect(info.command, equals('flutter build\n  apk'));
      expect(info.summary, equals('flutter build   apk'));
      expect(info.description, equals('Builds the app'));
      expect(info.errors, isEmpty);
      expect(info.errorMessage, isNull);
    });

    test('summarizes steps and parallel commands on one line', () {
      final steps = ScriptInfo(
        keys: ['check'],
        script: const Script(command: 'a\nb', steps: ['a', 'b']),
      );
      final parallel = ScriptInfo(
        keys: ['verify'],
        script: const Script(command: 'a\nb', parallel: ['a', 'b']),
      );

      expect(steps.summary, equals('a && b'));
      expect(parallel.summary, equals('a & b'));
    });

    test('reads positional arguments and reports their errors', () {
      final valid = ScriptInfo(
        keys: ['greet'],
        script: const Script(command: r'echo ${1} ${0}'),
      );
      final invalid = ScriptInfo(
        keys: ['bad'],
        script: const Script(command: r'echo ${1}'),
        errors: ['From the group.'],
      );

      expect(valid.commandArguments.map((a) => a.index), equals([0, 1]));
      expect(invalid.commandArguments, isEmpty);
      expect(
        invalid.errorMessage,
        equals(
          'From the group.\n'
          r'The script defines unused positional argument(s): ${0}',
        ),
      );
    });
  });
}
