import 'package:path/path.dart' as p;
import 'package:rps/rps.dart';

/// A package that belongs to a pub workspace.
class WorkspacePackage {
  /// The name from its `pubspec.yaml`.
  final String name;

  /// The directory of the package.
  final String path;

  /// The directory of the package relative to the workspace, with `/`.
  final String relativePath;

  /// Names of the packages it depends on, including dev dependencies.
  final Set<String> dependencies;

  /// Its parsed `pubspec.yaml`.
  final Pubspec pubspec;

  /// Creates a [WorkspacePackage].
  const WorkspacePackage({
    required this.name,
    required this.path,
    required this.relativePath,
    required this.dependencies,
    required this.pubspec,
  });
}

/// A pub workspace: a root `pubspec.yaml` with the `workspace` key.
class Workspace {
  static const _key = 'workspace';
  static final _unsupported = RegExp(r'[?\[\]{}]|\*\*');

  /// The directory of the workspace root.
  final String path;

  /// The packages of the workspace without its root, dependencies first.
  final List<WorkspacePackage> packages;

  Workspace._(this.path, this.packages);

  /// Finds the workspace of the current directory or the nearest one above.
  factory Workspace.find(FileSystem fs) {
    var directory = fs.currentDirectoryPath;
    while (true) {
      if (fs.fileExists(p.join(directory, Pubspec.filename))) {
        final pubspec = Pubspec.load(directory, fs: fs);
        if (pubspec.parsed[_key] != null) {
          return Workspace._load(directory, pubspec, fs);
        }
      }
      final parent = p.dirname(directory);
      if (parent == directory) {
        throw RpsConfigException(
          'Cannot find a pub workspace. No ${Pubspec.filename} file with '
          'the "$_key" key in the current directory or above it.',
        );
      }
      directory = parent;
    }
  }

  factory Workspace._load(String root, Pubspec rootPubspec, FileSystem fs) {
    final seen = {p.normalize(root)};
    final packages = <WorkspacePackage>[];

    void collect(String directory, Pubspec pubspec) {
      for (final path in _members(directory, pubspec, fs)) {
        if (!seen.add(p.normalize(path))) continue;
        final member = Pubspec.load(path, fs: fs);
        packages.add(
          WorkspacePackage(
            name: switch (member.parsed['name']) {
              final String name => name,
              _ => p.basename(path),
            },
            path: path,
            relativePath: p.split(p.relative(path, from: root)).join('/'),
            dependencies: {
              for (final key in const ['dependencies', 'dev_dependencies'])
                if (member.parsed[key] case final Map dependencies)
                  ...dependencies.keys.whereType<String>(),
            },
            pubspec: member,
          ),
        );
        collect(path, member);
      }
    }

    collect(root, rootPubspec);
    return Workspace._(root, _sort(packages));
  }

  static List<String> _members(
    String directory,
    Pubspec pubspec,
    FileSystem fs,
  ) {
    final entries = pubspec.parsed[_key];
    if (entries == null) return const [];
    if (entries is! List || entries.any((entry) => entry is! String)) {
      throw RpsConfigException(
        'The "$_key" key in ${p.join(directory, Pubspec.filename)} '
        'must be a list of paths.',
      );
    }
    return [
      for (final entry in entries.cast<String>())
        ..._expand(directory, entry, fs),
    ];
  }

  static List<String> _expand(String directory, String entry, FileSystem fs) {
    if (_unsupported.hasMatch(entry)) {
      throw RpsConfigException(
        'The workspace entry "$entry" uses a pattern that rps does not '
        'support. Only "*" within a path segment is supported.',
      );
    }

    bool hasPubspec(String path) =>
        fs.fileExists(p.join(path, Pubspec.filename));

    if (!entry.contains('*')) {
      final path = p.normalize(p.join(directory, entry));
      if (!hasPubspec(path)) {
        throw RpsConfigException(
          'The workspace package "$entry" has no ${Pubspec.filename} file.',
        );
      }
      return [path];
    }

    var paths = [directory];
    for (final segment in entry.split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (!segment.contains('*')) {
        paths = [for (final path in paths) p.join(path, segment)];
        continue;
      }
      final pattern = RegExp(
        '^${segment.split('*').map(RegExp.escape).join('.*')}\$',
      );
      paths = [
        for (final path in paths)
          if (fs.directoryExists(path))
            ...fs.listDirectoryPaths(path).where((child) {
              final name = p.basename(child);
              return !name.startsWith('.') && pattern.hasMatch(name);
            }).toList()
              ..sort(),
      ];
    }
    return [
      for (final path in paths)
        if (hasPubspec(path)) p.normalize(path),
    ];
  }

  static List<WorkspacePackage> _sort(List<WorkspacePackage> packages) {
    final names = {for (final package in packages) package.name};
    final pending = [...packages];
    final done = <String>{};
    final sorted = <WorkspacePackage>[];
    while (pending.isNotEmpty) {
      final index = pending.indexWhere(
        (package) => package.dependencies
            .where((name) => names.contains(name) && name != package.name)
            .every(done.contains),
      );
      // Packages that depend on each other keep the order of the list.
      final next = pending.removeAt(index < 0 ? 0 : index);
      done.add(next.name);
      sorted.add(next);
    }
    return sorted;
  }
}
