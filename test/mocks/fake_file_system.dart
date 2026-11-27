import 'package:rps/src/utils/file_system.dart';

class FakeFileSystem implements FileSystem {
  final Map<String, String> files;
  final Map<String, List<String>> directories;
  final String _currentDirectoryPath;
  final String? _resolvedPackagePath;
  final List<String> writtenFiles = [];

  FakeFileSystem({
    Map<String, String>? files,
    Map<String, List<String>>? directories,
    String currentDirectoryPath = '/project',
    String? resolvedPackagePath,
  })  : files = {
          for (final entry in (files ?? {}).entries)
            _normalize(entry.key): entry.value,
        },
        directories = directories ?? {},
        _currentDirectoryPath = currentDirectoryPath,
        _resolvedPackagePath = resolvedPackagePath;

  static String _normalize(String path) => path.replaceAll(r'\', '/');

  @override
  String get currentDirectoryPath => _currentDirectoryPath;

  @override
  bool fileExists(String path) => files.containsKey(_normalize(path));

  @override
  bool directoryExists(String path) =>
      directories.containsKey(_normalize(path));

  @override
  String readFile(String path) {
    final content = files[_normalize(path)];
    if (content == null) throw Exception('File not found: $path');
    return content;
  }

  @override
  void writeFile(String path, String contents) {
    writtenFiles.add(_normalize(path));
    files[_normalize(path)] = contents;
  }

  @override
  List<String> listFilePaths(String path) => directories[path] ?? [];

  @override
  Future<String?> resolvePackagePath(String packageUri) async =>
      _resolvedPackagePath;
}
