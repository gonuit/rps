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

    test(r'reads $cwd of groups and scripts', () {
      final root = _analyze(r'''
$cwd: packages
app:
  $cwd: packages/app
  build:
    $cwd: packages/app/android
    $script: ./gradlew build
bad:
  $cwd: 5
  $script: echo bad
''') as ScriptGroup;
      final app = root.children['app'] as ScriptGroup;

      expect(root.cwd, equals('packages'));
      expect(app.cwd, equals('packages/app'));
      expect(app.children['build']!.cwd, equals('packages/app/android'));
      expect(
        root.children['bad']!.error,
        equals(r'The "$cwd" key must be a path.'),
      );
    });

    test(r'reads $env and $envFile', () {
      final root = _analyze(r'''
$envFile: .env
$env:
  APP_ENV: dev
  PORT: 8080
  DEBUG: true
build:
  $envFile: [.env.build, .env.local]
  $env: {APP_ENV: prod}
  $script: echo build
''') as ScriptGroup;
      final build = root.children['build']!;

      expect(root.env, {'APP_ENV': 'dev', 'PORT': '8080', 'DEBUG': 'true'});
      expect(root.envFiles, equals(['.env']));
      expect(build.env, {'APP_ENV': 'prod'});
      expect(build.envFiles, equals(['.env.build', '.env.local']));
      expect(build.error, isNull);
    });

    test(r'reports invalid $env and $envFile', () {
      final root = _analyze(r'''
a:
  $env: text
  $script: echo a
b:
  $env: {LIST: [1], NOTHING: , 'A=B': x, OK: fine}
  $script: echo b
c:
  $envFile: {x: y}
  $script: echo c
''') as ScriptGroup;

      expect(root.children['a']!.error, r'The "$env" key must be a map.');
      expect(
        root.children['b']!.error,
        equals(
          'The environment variable "LIST" must be '
          'a string, a number or a boolean.\n'
          'The environment variable "NOTHING" must be '
          'a string, a number or a boolean.\n'
          'Invalid environment variable name: "A=B".',
        ),
      );
      expect(root.children['b']!.env, {'OK': 'fine'});
      expect(
        root.children['c']!.error,
        r'The "$envFile" key must be a path or a list of paths.',
      );
    });

    test(r'reads $steps as a script', () {
      final root = _analyze(r'''
check:
  $description: Checks the code
  $steps:
    - dart format .
    - rps analyze
    - $default: rm -rf build
      $windows: rd /s /q build
''', platform: const FakePlatform.windows()) as ScriptGroup;
      final check = root.children['check'] as Script;

      expect(
        check.steps,
        equals(['dart format .', 'rps analyze', 'rd /s /q build']),
      );
      expect(check.command, 'dart format .\nrps analyze\nrd /s /q build');
      expect(check.description, equals('Checks the code'));
      expect(check.error, isNull);
    });

    test(r'reports invalid $steps', () {
      final root = _analyze(r'''
both:
  $script: echo a
  $steps: [echo b]
text:
  $steps: echo a
empty:
  $steps: []
number:
  $steps: [echo a, 5]
''') as ScriptGroup;

      expect(
        root.children['both']!.error,
        r'Use either "$script" or "$steps", not both.',
      );
      expect(
        root.children['text']!.error,
        r'The "$steps" key must be a list of commands.',
      );
      expect(
        root.children['empty']!.error,
        r'The "$steps" key must be a list of commands.',
      );
      expect(
        root.children['number']!.error,
        'Invalid command. Cannot use type int (5) as a command.',
      );
    });

    test(r'reads $args', () {
      final root = _analyze(r'''
build:
  $args:
    flavor: dev
    target:
    build-number: 7
    obfuscate: false
  $script: flutter build ${target} --flavor ${flavor}
''') as ScriptGroup;
      final build = root.children['build'] as Script;

      expect(
        build.args.map((a) => (a.name, a.defaultValue, a.isRequired)),
        equals([
          ('flavor', 'dev', false),
          ('target', null, true),
          ('build-number', '7', false),
          ('obfuscate', 'false', false),
        ]),
      );
      expect(build.error, isNull);
    });

    test(r'reports invalid $args', () {
      final root = _analyze(r'''
list:
  $args: [a]
  $script: echo
names:
  $args: {'0': x, 'a b': y, ok: [1]}
  $script: echo
group:
  $args: {a: b}
  child: echo
''') as ScriptGroup;

      expect(root.children['list']!.error, r'The "$args" key must be a map.');
      expect(
        root.children['names']!.error,
        equals(
          'Invalid argument name: "0".\n'
          'Invalid argument name: "a b".\n'
          'The default value of the argument "ok" must be '
          'a string, a number or a boolean.',
        ),
      );
      expect(
        root.children['group']!.error,
        r'The "$args" key can be used only in a script.',
      );
    });

    test(r'reads $confirm', () {
      final root = _analyze(r'''
a:
  $confirm: true
  $script: echo a
b:
  $confirm: Drop the database?
  $steps: [echo b]
c:
  $confirm: false
  $script: echo c
d:
  $confirm: 5
  $script: echo d
group:
  $confirm: true
  child: echo
''') as ScriptGroup;
      Script script(String key) => root.children[key] as Script;

      expect((script('a').confirm, script('a').confirmMessage), (true, null));
      expect(script('b').confirmMessage, equals('Drop the database?'));
      expect(script('b').confirm, isTrue);
      expect(script('c').confirm, isFalse);
      expect(
        script('d').error,
        r'The "$confirm" key must be "true" or a question.',
      );
      expect(
        root.children['group']!.error,
        r'The "$confirm" key can be used only in a script.',
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
