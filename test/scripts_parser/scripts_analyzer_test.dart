import 'package:rps/rps.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../mocks/fake_platform.dart';

ScriptNode _analyze(String yaml,
    {FakePlatform platform = const FakePlatform()}) {
  return ScriptsAnalyzer(platform: platform).analyze(loadYaml(yaml));
}

void main() {
  group('ScriptsAnalyzer', () {
    test('reads a string as a script', () {
      final root = _analyze('build: flutter build') as ScriptGroup;
      final build = root.children['build'] as Script;

      expect(build.command, equals('flutter build'));
      expect(build.description, isNull);
      expect(build.error, isNull);
      expect(build.before, isNull);
      expect(build.after, isNull);
    });

    test('reads nested groups with hooks', () {
      final root = _analyze(r'''
build:
  $before: echo before
  $after: echo after
  android:
    apk: flutter build apk
''') as ScriptGroup;
      final build = root.children['build'] as ScriptGroup;
      final android = build.children['android'] as ScriptGroup;

      expect(build.before, equals('echo before'));
      expect(build.after, equals('echo after'));
      expect(build.children.keys, equals(['android']));
      expect((android.children['apk'] as Script).command, 'flutter build apk');
    });

    test(r'reads $script with a description and hooks', () {
      final root = _analyze(r'''
test:
  $before: rps get
  $script: flutter test
  $description: Runs tests
''') as ScriptGroup;
      final test = root.children['test'] as Script;

      expect(test.command, equals('flutter test'));
      expect(test.description, equals('Runs tests'));
      expect(test.before, equals('rps get'));
    });

    test('picks the command of the current platform', () {
      const yaml = r'''
clear:
  $script:
    $default: rm -rf cache
    $windows: rd /s /q cache
''';
      final windows =
          _analyze(yaml, platform: const FakePlatform.windows()) as ScriptGroup;
      final linux =
          _analyze(yaml, platform: const FakePlatform.linux()) as ScriptGroup;

      expect((windows.children['clear'] as Script).command, 'rd /s /q cache');
      expect((linux.children['clear'] as Script).command, 'rm -rf cache');
    });

    test('reports a missing platform command', () {
      final root = _analyze(r'''
tools:
  clear:
    $script:
      $windows: rd /s /q cache
''') as ScriptGroup;
      final clear = (root.children['tools'] as ScriptGroup).children['clear'];

      expect((clear as Script).command, equals('-'));
      expect(
        clear.error,
        equals(
          'No platform script key for the command: "tools clear". '
          r'Consider adding the key for the current platform: "$macos" '
          r'or the default script key: "$default".',
        ),
      );
    });

    test('reports values that are not commands', () {
      final root = _analyze(r'''
number: 5
empty:
scripted:
  $script: [a, b]
''') as ScriptGroup;

      expect(
        (root.children['number'] as Script).error,
        equals('Invalid command. Cannot use type int (5) as a command.'),
      );
      expect(
        (root.children['empty'] as Script).error,
        contains('Cannot use type Null (null)'),
      );
      expect(
        (root.children['scripted'] as Script).error,
        contains('Invalid command.'),
      );
    });

    test('reports a command in the root', () {
      final root = _analyze('echo hi');

      expect(
        (root as Script).error,
        equals('The root key "scripts" cannot contain commands.'),
      );
    });

    test('reports unknown special keys', () {
      final root = _analyze(r'''
build:
  $skript: echo build
  apk: echo apk
test:
  $script: dart test
  $descripton: Runs tests
  $after: echo done
''') as ScriptGroup;
      final build = root.children['build'] as ScriptGroup;

      expect(build.error, equals(r'Unknown key: "$skript".'));
      expect(build.children.keys, equals(['apk']));
      expect(
        root.children['test']!.error,
        equals(r'Unknown key: "$descripton".'),
      );
    });

    test('ignores special keys that are not strings', () {
      final root = _analyze(r'''
build:
  $before: 5
  $description: [x]
  $script: echo build
''') as ScriptGroup;
      final build = root.children['build'] as Script;

      expect(build.before, isNull);
      expect(build.description, isNull);
      expect(build.error, isNull);
    });
  });
}
