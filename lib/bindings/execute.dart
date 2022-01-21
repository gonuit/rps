import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

typedef ExecuteNative = Int32 Function(Pointer<Utf8> command);
typedef Execute = int Function(Pointer<Utf8> command);

Future<int> execute(String command) async {
  const rootLibrary = 'package:rps/rps.dart';
  final uri = await Isolate.resolvePackageUri(Uri.parse(rootLibrary));
  if (uri == null) {
    print('Library cannot be loaded.');
    exit(1);
  }

  final root = path.fromUri(uri.resolve('native').path);
  // Open the dynamic library
  late String libraryPath;
  if (Platform.isMacOS) {
    libraryPath = path.join(root, 'librps.dylib');
  } else if (Platform.isWindows) {
    libraryPath = path.join(root, 'rps.dll');
  } else {
    libraryPath = path.join(root, 'librps.so');
  }

  final dylib = DynamicLibrary.open(libraryPath);
  final execute = dylib.lookupFunction<ExecuteNative, Execute>('execute');

  final code = execute(command.toNativeUtf8());

  return code;
}
