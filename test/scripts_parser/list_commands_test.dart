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

    test(r'commands use the nearest $cwd', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(r'''
scripts:
  $cwd: root-dir
  plain: echo plain
  app:
    $cwd: packages/app
    $before: echo before
    build: echo build
    android:
      $cwd: packages/app/android
      $script: echo android
    ref: rps plain
'''),
        platform: const FakePlatform(),
      );

      List<String?> directories(List<String> arguments) => parser
          .getCommandsToExecute(arguments)
          .whereType<CommandExecuted>()
          .map((e) => e.workingDirectory)
          .toList();

      expect(directories(['plain']), equals(['root-dir']));
      expect(
        directories(['app', 'build']),
        equals(['packages/app', 'packages/app']),
      );
      expect(
        directories(['app', 'android']),
        equals(['packages/app', 'packages/app/android']),
      );
      expect(directories(['app', 'ref']), equals(['packages/app', 'root-dir']));
      expect(
        parser.listCommands().map((e) => e.workingDirectory),
        equals([
          'root-dir',
          'packages/app',
          'packages/app/android',
          'packages/app'
        ]),
      );
    });

    test(r'commands merge $env and $envFile from their groups', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(r'''
scripts:
  $envFile: .env
  $env: {A: root, B: root}
  plain: echo plain
  app:
    $envFile: .env.app
    $env: {B: app, C: app}
    $after: echo after
    build:
      $env: {C: build}
      $script: echo build
    ref: rps plain
'''),
        platform: const FakePlatform(),
      );

      List<CommandExecuted> commands(List<String> arguments) => parser
          .getCommandsToExecute(arguments)
          .whereType<CommandExecuted>()
          .toList();

      final [build, after] = commands(['app', 'build']);
      expect(build.environment, {'A': 'root', 'B': 'app', 'C': 'build'});
      expect(build.envFiles, equals(['.env', '.env.app']));
      expect(after.environment, {'A': 'root', 'B': 'app', 'C': 'app'});

      final [plain, _] = commands(['app', 'ref']);
      expect(plain.environment, {'A': 'root', 'B': 'root'});
      expect(plain.envFiles, equals(['.env']));
    });

    group(r'$steps', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(r'''
scripts:
  clean: echo clean
  build: echo build ${0}
  release:
    $before: echo before
    $steps:
      - rps clean
      - echo ${1}
      - rps build ${0}
      - rps clean
    $after: echo after
  gap:
    $steps:
      - echo ${0}
      - echo ${2}
'''),
        platform: const FakePlatform(),
      );

      test('resolves steps and references in order', () {
        final events = parser.getCommandsToExecute(['release', 'apk', 'v1']);
        final commands = events
            .whereType<CommandExecuted>()
            .map((e) => (e.compile(), e.step))
            .toList();

        expect(commands, [
          ('echo before', null),
          ('echo clean', null),
          ('echo v1', (2, 4)),
          ('echo build apk', null),
          ('echo clean', null),
          ('echo after', null),
        ]);
        expect(
          events.whereType<CommandReferenced>().map((e) => e.step),
          equals([(1, 4), (3, 4), (4, 4)]),
        );
      });

      test('rejects additional arguments', () {
        expect(
          () => parser.getCommandsToExecute(['release', 'apk', 'v1', 'more']),
          throwsA(isA<RpsUsageException>().having(
            (e) => e.message,
            'message',
            equals(
              'The script "release" runs several commands, '
              'so it does not accept additional arguments: more',
            ),
          )),
        );
      });

      test('requires the arguments used by the steps', () {
        expect(
          () => parser.getCommandsToExecute(['release']),
          throwsA(isA<RpsUsageException>()),
        );
        expect(
          () => parser
              .getCommandsToExecute(['release', 'apk'])
              .whereType<CommandExecuted>()
              .map((e) => e.compile())
              .toList(),
          throwsA(isA<RpsUsageException>()),
        );
      });

      test('reports a gap in positional arguments', () {
        expect(
          parser.listCommands().last.errors.single,
          contains(r'unused positional argument(s): ${1}'),
        );
        expect(
          () => parser.getCommandsToExecute(['gap', 'a', 'b', 'c']),
          throwsA(isA<RpsConfigException>()),
        );
      });
    });

    group(r'$args', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(r'''
scripts:
  build:
    $args:
      flavor: dev
      target:
    $script: flutter build ${target} --flavor ${ flavor } ${HOME} ${0}
  short: rps build --target apk
  release:
    $args:
      flavor:
    $steps:
      - echo releasing ${flavor}
      - rps build --target ipa --flavor ${flavor} x
  plain: echo
'''),
        platform: const FakePlatform(),
      );

      String compile(List<String> arguments) => parser
          .getCommandsToExecute(arguments)
          .whereType<CommandExecuted>()
          .map((e) => e.compile())
          .join(' && ');

      test('fills declared names and leaves the rest to the shell', () {
        expect(
          compile(['build', '--target', 'apk', 'x']),
          equals(r'flutter build apk --flavor dev ${HOME} x'),
        );
      });

      test('accepts both forms, in any position, last one wins', () {
        expect(
          compile([
            'build',
            'x',
            '--flavor=prod',
            '--release',
            '--target',
            'apk',
            '--target=ipa',
          ]),
          equals(r'flutter build ipa --flavor prod ${HOME} x --release'),
        );
      });

      test('quotes values for the shell', () {
        expect(
          compile(['build', '--target', 'a b; rm', '--flavor=', 'x']),
          equals(r"flutter build 'a b; rm' --flavor '' ${HOME} x"),
        );
      });

      test('stops reading names after --', () {
        expect(
          compile(['build', '--target', 'apk', 'x', '--', '--flavor', 'p']),
          equals(r'flutter build apk --flavor dev ${HOME} x --flavor p'),
        );
      });

      test('reports missing arguments and values', () {
        expect(
          () => compile(['build', 'x']),
          throwsA(isA<RpsUsageException>().having(
            (e) => e.message,
            'message',
            'The script "build" requires the argument(s): --target.',
          )),
        );
        expect(
          () => compile(['build', 'x', '--target']),
          throwsA(isA<RpsUsageException>().having(
            (e) => e.message,
            'message',
            'The argument "--target" of the script "build" needs a value.',
          )),
        );
      });

      test('works through references and in steps', () {
        expect(
          compile(['short', 'x', '--flavor', 'qa']),
          equals(r'flutter build apk --flavor qa ${HOME} x'),
        );
        expect(
          compile(['release', '--flavor', 'prod']),
          equals(
            'echo releasing prod && '
            r'flutter build ipa --flavor prod ${HOME} x',
          ),
        );
      });

      test('scripts without the key keep every argument', () {
        expect(compile(['plain', '--flavor', 'x', '--']), 'echo --flavor x --');
      });

      test('lists the declared arguments', () {
        expect(
          parser.listCommands().first.declaredArguments.map((a) => a.name),
          equals(['flavor', 'target']),
        );
      });
    });

    test(r'scripts with $confirm ask before they run', () {
      final parser = ScriptsParser(
        source: MockedScriptSource(r'''
scripts:
  db:
    reset:
      $confirm: true
      $before: echo before
      $script: echo reset
    drop:
      $confirm: Drop everything?
      $script: echo drop
  all:
    $steps:
      - rps db reset
      - rps db drop
  safe: echo safe
'''),
        platform: const FakePlatform(),
      );

      List<String> questions(List<String> arguments) => parser
          .getCommandsToExecute(arguments)
          .whereType<ConfirmationRequired>()
          .map((e) => '${e.path}: ${e.message}')
          .toList();

      expect(
        questions(['db', 'reset']),
        equals(['db reset: Run the script "db reset"?']),
      );
      expect(
        parser.getCommandsToExecute(['db', 'reset']).first,
        isA<ConfirmationRequired>(),
      );
      expect(
        questions(['all']),
        equals([
          'db reset: Run the script "db reset"?',
          'db drop: Drop everything?',
        ]),
      );
      expect(questions(['safe']), isEmpty);
      expect(
        parser.listCommands().map((e) => e.confirmation),
        equals([
          'Run the script "db reset"?',
          'Drop everything?',
          null,
          null,
        ]),
      );
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
