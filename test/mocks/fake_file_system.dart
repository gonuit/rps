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
  })  : files = files ?? {},
        directories = directories ?? {},
        _currentDirectoryPath = currentDirectoryPath,
        _resolvedPackagePath = resolvedPackagePath;

  @override
  String get currentDirectoryPath => _currentDirectoryPath;

  @override
  bool fileExists(String path) => files.containsKey(path);

  @override
  String readFile(String path) {
    final content = files[path];
    if (content == null) throw Exception('File not found: $path');
    return content;
  }

  @override
  void writeFile(String path, String contents) {
    writtenFiles.add(path);
    files[path] = contents;
  }

  @override
  List<String> listFilePaths(String path) => directories[path] ?? [];

  @override
  Future<String?> resolvePackagePath(String packageUri) async =>
      _resolvedPackagePath;
}
