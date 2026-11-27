import 'package:rps/rps.dart';
import 'package:test/test.dart';

import '../mocks/fake_file_system.dart';

String _pubspec(String name, {List<String> deps = const [], String? extra}) {
  return [
    'name: $name',
    if (deps.isNotEmpty) 'dependencies:',
    for (final dep in deps) '  $dep: any',
    if (extra != null) extra,
  ].join('\n');
}

Workspace _find(Map<String, String> files, {String cwd = '/ws'}) {
  return Workspace.find(
      FakeFileSystem(files: files, currentDirectoryPath: cwd));
}

List<String> _paths(Workspace workspace) =>
    workspace.packages.map((package) => package.relativePath).toList();

void main() {
  group('Workspace', () {
    test('reads the listed packages without the root', () {
      final workspace = _find({
        '/ws/pubspec.yaml': 'name: root\nworkspace:\n  - packages/a\n  - b',
        '/ws/packages/a/pubspec.yaml': _pubspec('a'),
        '/ws/b/pubspec.yaml': _pubspec('b'),
      });

      expect(_paths(workspace), equals(['packages/a', 'b']));
      expect(workspace.packages.map((package) => package.name), ['a', 'b']);
    });

    test('is found from a directory inside a package', () {
      final workspace = _find(
        {
          '/ws/pubspec.yaml': 'name: root\nworkspace: [packages/a]',
          '/ws/packages/a/pubspec.yaml': _pubspec('a'),
        },
        cwd: '/ws/packages/a/lib/src',
      );

      expect(_paths(workspace), equals(['packages/a']));
    });

    test('expands * to the directories that are packages', () {
      final workspace = _find({
        '/ws/pubspec.yaml': 'name: root\nworkspace:\n  - packages/*\n'
            '  - apps/app_*',
        '/ws/packages/b/pubspec.yaml': _pubspec('b'),
        '/ws/packages/a/pubspec.yaml': _pubspec('a'),
        '/ws/packages/notes/readme.md': '',
        '/ws/packages/.hidden/pubspec.yaml': _pubspec('hidden'),
        '/ws/apps/app_one/pubspec.yaml': _pubspec('one'),
        '/ws/apps/tool/pubspec.yaml': _pubspec('tool'),
      });

      expect(
        _paths(workspace),
        equals(['packages/a', 'packages/b', 'apps/app_one']),
      );
    });

    test('includes the packages of a nested workspace', () {
      final files = {
        '/ws/pubspec.yaml': 'name: root\nworkspace: [server, client]',
        '/ws/server/pubspec.yaml':
            _pubspec('server', extra: 'workspace: [api]'),
        '/ws/server/api/pubspec.yaml': _pubspec('api'),
        '/ws/client/pubspec.yaml': _pubspec('client'),
      };

      expect(_paths(_find(files)), equals(['server', 'server/api', 'client']));
      expect(_paths(_find(files, cwd: '/ws/server')), equals(['api']));
    });

    test('puts dependencies first and keeps the listed order otherwise', () {
      final workspace = _find({
        '/ws/pubspec.yaml': 'name: root\nworkspace: [app, ui, core, tool]',
        '/ws/app/pubspec.yaml': _pubspec('app', deps: ['ui', 'core', 'http']),
        '/ws/ui/pubspec.yaml':
            _pubspec('ui', extra: 'dev_dependencies:\n  core: any'),
        '/ws/core/pubspec.yaml': _pubspec('core'),
        '/ws/tool/pubspec.yaml': _pubspec('tool'),
      });

      expect(_paths(workspace), equals(['core', 'ui', 'app', 'tool']));
    });

    test('keeps the listed order for packages that depend on each other', () {
      final workspace = _find({
        '/ws/pubspec.yaml': 'name: root\nworkspace: [a, b, c]',
        '/ws/a/pubspec.yaml': _pubspec('a', deps: ['b']),
        '/ws/b/pubspec.yaml': _pubspec('b', deps: ['a']),
        '/ws/c/pubspec.yaml': _pubspec('c'),
      });

      expect(_paths(workspace), equals(['c', 'a', 'b']));
    });

    test('fails outside of a workspace', () {
      expect(
        () => _find({'/ws/pubspec.yaml': 'name: plain'}),
        throwsA(isA<RpsConfigException>()),
      );
    });

    test('fails for a listed package without a pubspec', () {
      expect(
        () => _find({'/ws/pubspec.yaml': 'name: root\nworkspace: [gone]'}),
        throwsA(
          isA<RpsConfigException>().having(
            (e) => e.message,
            'message',
            contains('"gone"'),
          ),
        ),
      );
    });

    test('fails for patterns other than *', () {
      for (final entry in ['packages/**', 'packages/{a,b}', 'pkg?']) {
        expect(
          () =>
              _find({'/ws/pubspec.yaml': 'name: root\nworkspace: ["$entry"]'}),
          throwsA(isA<RpsConfigException>()),
          reason: entry,
        );
      }
    });

    test('fails when the workspace key is not a list of paths', () {
      expect(
        () => _find({'/ws/pubspec.yaml': 'name: root\nworkspace: packages'}),
        throwsA(isA<RpsConfigException>()),
      );
    });
  });
}
