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

    test('returns empty for missing command', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(_missingScripts),
        platform: const FakePlatform(),
      );

      final events = parser.getCommandsToExecute(['nonexistent']);
      expect(events, isEmpty);
    });

    test('detects script cycle', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(_cycleScripts),
        platform: const FakePlatform(),
      );

      expect(
        () => parser.getCommandsToExecute(['a']),
        throwsA(isA<ScriptParserException>()),
      );
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
