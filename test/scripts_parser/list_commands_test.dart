import 'package:rps/rps.dart';
import 'package:test/test.dart';

import '../mocks/fake_platform.dart';
import '../mocks/script_source.mock.dart';

const _simpleScripts = r'''
name: test
version: 1.0.0
scripts:
  echo: echo hello
  nested:
    child: echo nested
  with-desc:
    $script: echo desc
    $description: A described command
  platform-script:
    $script:
      $macos: echo mac
      $linux: echo linux
      $windows: echo win
      $default: echo default
    $description: Platform specific
  platform-no-match:
    $script:
      $android: echo android
    $description: No platform match
  invalid-value: 123
''';

const _cycleScripts = r'''
name: test
version: 1.0.0
scripts:
  a: rps b
  b: rps a
''';

const _missingScripts = r'''
name: test
version: 1.0.0
scripts:
  build:
    android:
      apk: echo apk
''';

void main() {
  group('ScriptsParser.listCommands', () {
    test('lists simple commands', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(_simpleScripts),
        platform: const FakePlatform(),
      );
      final commands = parser.listCommands();
      final names = commands.map((c) => c.path).toList();

      expect(names, contains('echo'));
      expect(names, contains('nested child'));
    });

    test('lists described commands', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(_simpleScripts),
        platform: const FakePlatform(),
      );
      final commands = parser.listCommands();
      final desc = commands.firstWhere((c) => c.path == 'with-desc');

      expect(desc.description, equals('A described command'));
    });

    test('resolves platform-specific \$script map for macos', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(_simpleScripts),
        platform: const FakePlatform(),
      );
      final commands = parser.listCommands();
      final cmd = commands.firstWhere((c) => c.path == 'platform-script');

      expect(cmd.command, equals('echo mac'));
    });

    test('resolves platform-specific \$script map for linux', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(_simpleScripts),
        platform: const FakePlatform.linux(),
      );
      final commands = parser.listCommands();
      final cmd = commands.firstWhere((c) => c.path == 'platform-script');

      expect(cmd.command, equals('echo linux'));
    });

    test('resolves platform-specific \$script map for windows', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(_simpleScripts),
        platform: const FakePlatform.windows(),
      );
      final commands = parser.listCommands();
      final cmd = commands.firstWhere((c) => c.path == 'platform-script');

      expect(cmd.command, equals('echo win'));
    });

    test('falls back to \$default when platform not matched', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(_simpleScripts),
        platform: const FakePlatform(
          isWindows: false,
          isMacOS: false,
          isLinux: false,
          operatingSystem: 'fuchsia',
        ),
      );
      final commands = parser.listCommands();
      final cmd = commands.firstWhere((c) => c.path == 'platform-script');

      expect(cmd.command, equals('echo default'));
    });

    test('reports error when no platform key matches and no default', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(_simpleScripts),
        platform: const FakePlatform(),
      );
      final commands = parser.listCommands();
      final cmd = commands.firstWhere((c) => c.path == 'platform-no-match');

      expect(cmd.errors, isNotEmpty);
    });

    test('reports error for invalid value types', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(_simpleScripts),
        platform: const FakePlatform(),
      );
      final commands = parser.listCommands();
      final cmd = commands.firstWhere((c) => c.path == 'invalid-value');

      expect(cmd.errors, isNotEmpty);
    });
  });

  group('ScriptsParser.getCommandsToExecute', () {
    test('resolves simple command', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(_simpleScripts),
        platform: const FakePlatform(),
      );
      final events = parser.getCommandsToExecute(['echo']);

      expect(events, hasLength(1));
      expect(events.first, isA<CommandExecuted>());
      expect((events.first as CommandExecuted).command, equals('echo hello'));
    });

    test('resolves nested command', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(_missingScripts),
        platform: const FakePlatform(),
      );
      final events = parser.getCommandsToExecute(['build', 'android', 'apk']);

      expect(events, hasLength(1));
      expect((events.first as CommandExecuted).command, equals('echo apk'));
    });

    test('resolves platform-specific command', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(_simpleScripts),
        platform: const FakePlatform.linux(),
      );
      final events = parser.getCommandsToExecute(['platform-script']);

      expect(events, hasLength(1));
      expect((events.first as CommandExecuted).command, equals('echo linux'));
    });

    test('throws on missing nested path', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(_missingScripts),
        platform: const FakePlatform(),
      );

      expect(
        () => parser.getCommandsToExecute(['build', 'android']),
        throwsA(isA<RpsException>()),
      );
    });

    test('throws for missing command', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(_missingScripts),
        platform: const FakePlatform(),
      );

      expect(
        () => parser.getCommandsToExecute(['nonexistent']),
        throwsA(isA<RpsException>().having(
          (e) => e.message,
          'message',
          contains('"nonexistent" not found'),
        )),
      );
    });

    test('throws for missing nested command under hooks', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(r'''
scripts:
  build:
    $before: echo before
    $after: echo after
    apk: echo apk
'''),
        platform: const FakePlatform(),
      );

      expect(
        () => parser.getCommandsToExecute(['build', 'foo']),
        throwsA(isA<RpsException>().having(
          (e) => e.message,
          'message',
          contains('"build foo" not found'),
        )),
      );
    });

    test('throws for reference to missing command', () {
      final parser = ScriptsParser(
        source: MockedScriptSource('''
scripts:
  ref: rps nonexistent
'''),
        platform: const FakePlatform(),
      );

      expect(
        () => parser.getCommandsToExecute(['ref']),
        throwsA(isA<RpsException>().having(
          (e) => e.message,
          'message',
          contains('"nonexistent" not found'),
        )),
      );
    });

    test('ignores trailing whitespace in references', () {
      final parser = ScriptsParser(
        source: MockedScriptSource('''
scripts:
  say: echo
  trail: "rps say "
'''),
        platform: const FakePlatform(),
      );

      final events = parser.getCommandsToExecute(['trail']);
      expect((events.last as CommandExecuted).compile(), 'echo');
    });

    test('detects script cycle', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(_cycleScripts),
        platform: const FakePlatform(),
      );

      expect(
        () => parser.getCommandsToExecute(['a']),
        throwsA(isA<RpsConfigException>()),
      );
    });

    test('scripts inherit the error of their group', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(r'''
scripts:
  build:
    $befor: echo typo
    apk: echo apk
  ok: echo ok
'''),
        platform: const FakePlatform(),
      );

      final commands = parser.listCommands();
      expect(commands.first.errors, equals([r'Unknown key: "$befor".']));
      expect(commands.last.errors, isEmpty);
      expect(
        () => parser.getCommandsToExecute(['build', 'apk']),
        throwsA(isA<RpsConfigException>()),
      );
      expect(parser.getCommandsToExecute(['ok']), hasLength(1));
    });

    test('detects a cycle through a hook', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(r'''
scripts:
  a:
    $before: rps a
    $script: echo a
  build:
    $before: rps check
    apk: echo apk
  check: rps build apk
'''),
        platform: const FakePlatform(),
      );

      expect(
        () => parser.getCommandsToExecute(['a']),
        throwsA(isA<RpsConfigException>().having(
          (e) => e.message,
          'message',
          equals(r'Script cycle detected: a $before → a $before'),
        )),
      );
      expect(
        () => parser.getCommandsToExecute(['build', 'apk']),
        throwsA(isA<RpsConfigException>()),
      );
    });

    test('allows a script to be referenced more than once', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(r'''
scripts:
  clean: echo clean
  build:
    $before: rps clean
    $script: echo build
    $after: rps clean
'''),
        platform: const FakePlatform(),
      );

      final commands = parser
          .getCommandsToExecute(['build'])
          .whereType<CommandExecuted>()
          .map((e) => e.command);
      expect(commands, equals(['echo clean', 'echo build', 'echo clean']));
    });

    test('defaults to run when no arguments', () {
      final scripts = r'''
name: test
version: 1.0.0
scripts:
  run: echo default-run
''';
      final parser = ScriptsParser(
        source: MockedScriptSource(scripts),
        platform: const FakePlatform(),
      );
      final events = parser.getCommandsToExecute([]);

      expect(events, hasLength(1));
      expect((events.first as CommandExecuted).command,
          equals('echo default-run'));
    });

    test('throws on platform-specific with no match in execute path', () {
      final scripts = r'''
name: test
version: 1.0.0
scripts:
  no-match:
    $script:
      $android: echo android
''';
      final parser = ScriptsParser(
        source: MockedScriptSource(scripts),
        platform: const FakePlatform(),
      );

      expect(
        () => parser.getCommandsToExecute(['no-match']),
        throwsA(isA<RpsException>()),
      );
    });
  });
}
