import 'package:rps/rps.dart';
import 'package:test/test.dart';

import '../mocks/fake_executor.dart';
import '../mocks/fake_file_system.dart';
import '../mocks/fake_platform.dart';
import '../mocks/fake_prompt.dart';

const _root = 'name: root\nworkspace: [app, core, docs]\n'
    'scripts:\n  test: echo root';

Map<String, String> _workspace({String app = 'test: echo app'}) => {
      '/ws/pubspec.yaml': _root,
      '/ws/app/pubspec.yaml': 'name: app\ndependencies:\n  core: any\n'
          'scripts:\n  $app\n  only-app: echo only',
      '/ws/core/pubspec.yaml': 'name: core',
      '/ws/core/rps.yaml': 'scripts:\n  test: echo core \${0}\n',
      '/ws/docs/pubspec.yaml': 'name: docs\nscripts:\n  build: echo docs',
    };

class _Run {
  _Run(this.executor, this.output, this.errors);

  final FakeExecutor executor;
  final StringBuffer output;
  final StringBuffer errors;

  List<String?> get directories => [
        for (final directory in executor.workingDirectories)
          directory?.replaceAll(r'\', '/'),
      ];
}

Future<_Run> _run(
  List<String> arguments, {
  Map<String, String>? files,
  FakeExecutor? executor,
  bool dryRun = false,
  bool interactive = false,
  Prompt? prompt,
  String cwd = '/ws',
  _Run? into,
}) async {
  final fs = FakeFileSystem(
    files: files ?? _workspace(),
    currentDirectoryPath: cwd,
  );
  final run =
      into ?? _Run(executor ?? FakeExecutor(), StringBuffer(), StringBuffer());
  await RunAllCommand(
    runner: ScriptRunner(
      executor: run.executor,
      console: Console(sink: run.output, ansi: false),
      errors: Console(sink: run.errors, ansi: false),
      dryRun: dryRun,
      interactive: interactive,
      prompt: prompt ?? FakePrompt(),
      fs: fs,
      processEnvironment: const {},
    ),
    workspace: Workspace.find(fs),
    fs: fs,
    platform: const FakePlatform(),
  ).run(arguments);
  return run;
}

void main() {
  group('RunAllCommand', () {
    test('runs the script in the packages that define it', () async {
      final run = await _run(['test', 'x']);

      expect(run.executor.executions, equals(['echo core x', 'echo app x']));
      expect(run.directories, equals(['/ws/core', '/ws/app']));
      expect(
        run.output.toString(),
        allOf(
          contains('▶ core (core)\n'),
          contains('▶ app (app)\n'),
          contains('✓ Ran "test x" in 2 package(s).'),
          isNot(contains('docs')),
          isNot(contains('root')),
        ),
      );
    });

    test('accepts the run command name', () async {
      final run = await _run(['run', 'only-app']);

      expect(run.executor.executions, equals(['echo only']));
    });

    test('fails when no package defines the script', () async {
      await expectLater(
        _run(['deploy']),
        throwsA(
          isA<RpsUsageException>().having(
            (e) => e.message,
            'message',
            'No package of the workspace defines the script "deploy".',
          ),
        ),
      );
    });

    test('stops at the first package that fails', () async {
      final run =
          _Run(FakeExecutor(exitCode: 3), StringBuffer(), StringBuffer());

      await expectLater(
        _run(['test', 'x'], into: run),
        throwsA(
          isA<ScriptFailedException>()
              .having((e) => e.exitCode, 'exitCode', 3)
              .having(
                (e) => e.message,
                'message',
                'The script "test x" failed in 1 of 2 package(s): core. '
                    'Not run: app.',
              ),
        ),
      );
      expect(run.executor.executions, equals(['echo core x']));
      expect(run.errors.toString(), contains('non zero exit code (3)'));
    });

    test('runs nothing when a package has a broken script', () async {
      final run = _Run(FakeExecutor(), StringBuffer(), StringBuffer());

      await expectLater(
        _run(
          ['test', 'x'],
          files: _workspace(app: r'test: echo ${1}'),
          into: run,
        ),
        throwsA(isA<RpsConfigException>()),
      );
      await expectLater(
        _run(['test'], into: run),
        throwsA(
          isA<RpsUsageException>().having(
            (e) => e.message,
            'message',
            startsWith('In the package "core": '),
          ),
        ),
      );
      expect(run.executor.executions, isEmpty);
    });

    test('resolves paths and references inside each package', () async {
      final run = await _run(
        ['test'],
        files: {
          '/ws/pubspec.yaml': 'name: root\nworkspace: [app]',
          '/ws/app/pubspec.yaml': 'name: app',
          '/ws/app/rps.yaml': r'''
scripts:
  $envFile: .env
  test:
    $cwd: tool
    $before: rps prepare
    $script: echo test
  prepare: echo prepare
''',
          '/ws/app/.env': 'A=1',
          '/ws/app/tool/x': '',
        },
      );

      expect(run.executor.executions, equals(['echo prepare', 'echo test']));
      expect(run.directories, equals(['/ws/app', '/ws/app/tool']));
      expect(
          run.executor.environments,
          equals([
            {'A': '1'},
            {'A': '1'}
          ]));
    });

    test('uses the interpreter of each package', () async {
      final run = await _run(
        ['test'],
        files: {
          '/ws/pubspec.yaml': 'name: root\nworkspace: [a, b]',
          '/ws/a/pubspec.yaml': 'name: a\nscripts:\n  test: echo a',
          '/ws/b/pubspec.yaml': 'name: b',
          '/ws/b/rps.yaml': 'macos:\n  interpreter: zsh\n'
              'linux:\n  interpreter: zsh\nscripts:\n  test: echo b',
        },
      );

      expect(
        run.executor.shells.map((shell) => shell!.executable),
        equals(['bash', 'zsh']),
      );
    });

    test('asks for all confirmations before anything runs', () async {
      final files = {
        '/ws/pubspec.yaml': 'name: root\nworkspace: [a, b]',
        for (final name in ['a', 'b'])
          '/ws/$name/pubspec.yaml': 'name: $name\nscripts:\n  drop:\n'
              '    \$confirm: Drop $name?\n    \$script: echo $name',
      };
      final prompt = FakePrompt(['y', 'n']);
      final run = _Run(FakeExecutor(), StringBuffer(), StringBuffer());

      await expectLater(
        _run(['drop'],
            files: files, interactive: true, prompt: prompt, into: run),
        throwsA(isA<RpsException>()),
      );
      expect(prompt.questions, ['Drop a? (y/N)', 'Drop b? (y/N)']);
      expect(run.executor.executions, isEmpty);
    });

    test('prints the commands of every package on a dry run', () async {
      final run = await _run(['test', 'x'], dryRun: true);

      expect(run.executor.executions, isEmpty);
      expect(
        run.output.toString(),
        allOf(
          contains(r'$ echo core x'),
          contains(r'$ echo app x'),
          isNot(contains('✓')),
        ),
      );
    });
  });
}
