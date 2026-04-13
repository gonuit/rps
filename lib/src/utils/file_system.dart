import 'dart:io' as io;
import 'dart:isolate';

/// Abstraction over file-system operations for testability.
abstract interface class FileSystem {
  /// Returns the path of the current working directory.
  String get currentDirectoryPath;

  /// Returns `true` if a file exists at [path].
  bool fileExists(String path);

  /// Reads the entire file at [path] as a string.
  String readFile(String path);

  /// Writes [contents] to the file at [path], creating it if necessary.
  void writeFile(String path, String contents);

  /// Returns the paths of all files directly inside the directory at [path].
  List<String> listFilePaths(String path);

  /// Resolves a `package:` URI to a directory path, or `null` if unresolvable.
  Future<String?> resolvePackagePath(String packageUri);
}

/// Default [FileSystem] backed by `dart:io`.
class SystemFileSystem implements FileSystem {
  /// Creates a [SystemFileSystem].
  const SystemFileSystem();

  @override
  String get currentDirectoryPath => io.Directory.current.path;

  @override
  bool fileExists(String path) => io.File(path).existsSync();

  @override
  String readFile(String path) => io.File(path).readAsStringSync();

  @override
  void writeFile(String path, String contents) {
    io.File(path).writeAsStringSync(contents, flush: true);
  }

  @override
  List<String> listFilePaths(String path) {
    return io.Directory(path)
        .listSync()
        .whereType<io.File>()
        .map((f) => f.path)
        .toList();
  }

  @override
  Future<String?> resolvePackagePath(String packageUri) async {
    final uri = await Isolate.resolvePackageUri(Uri.parse(packageUri));
    if (uri == null) return null;
    return io.Directory.fromUri(uri.resolve('..')).path;
  }
}
