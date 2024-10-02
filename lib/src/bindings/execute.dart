import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import 'package:rps/rps.dart';
import 'package:rps/src/models/interpreter.dart';

typedef ExecuteNative = Int32 Function(
  Pointer<Utf8> command,
  Pointer<Utf8>? interpreter,
);
typedef Execute = int Function(
  Pointer<Utf8> command,
  Pointer<Utf8>? interpreter,
);
typedef ExecuteFunction = Future<int> Function(
  String command,
);

Future<int> execute(
  String command, {
  bool verbose = false,
  Interpreter? interpreter,
  StringSink? out,
}) async {
  final bindings = <Abi, String>{
    Abi.windowsX64: 'rps_x64.dll',
    Abi.linuxX64: 'librps_x64.so',
    Abi.linuxArm64: 'librps_aarch64.so',
    Abi.macosX64: 'librps.dylib',
    Abi.macosArm64: 'librps.dylib',
  };

  if (!Platform.isWindows && interpreter is WindowsInterpreter) {
    throw RpsException(
      'The Windows interpreter cannot be used on ${Platform.operatingSystem}.',
    );
  }
  if (!Platform.isLinux &&
      !Platform.isMacOS &&
      interpreter is UnixInterpreter) {
    throw RpsException(
      'The Unix interpreter cannot be used on ${Platform.operatingSystem}.',
    );
  }

  if (verbose) {
    if (interpreter != null) {
      out?.writeln("Using interpreter: ${interpreter.value}");
    } else {
      out?.writeln("Using default interpreter");
    }
  }

  const rootLibrary = 'package:rps/rps.dart';
  final uri = await Isolate.resolvePackageUri(Uri.parse(rootLibrary));
  if (uri == null) {
    throw RpsException('Cannot load the library.');
  }

  final platform = Abi.current();
  if (verbose) {
    out?.writeln("Running on platform: $platform");
  }

  String? libraryName = bindings[platform];

  if (verbose) {
    out?.writeln("Dynamic library file selected: $libraryName");
  }

  if (libraryName == null) {
    throw RpsException(
        'Current platform ($platform) is currently not supported.');
  }

  final root = path.fromUri(uri.resolve(path.join('..', 'native')).path);
  final libraryPath = path.join(root, libraryName);

  if (verbose) {
    out?.writeln("Dynamic library path: $libraryPath");
  }

  final dylib = DynamicLibrary.open(libraryPath);
  final execute = dylib.lookupFunction<ExecuteNative, Execute>('execute');

  final commandC = command.toNativeUtf8();
  final interpreterC =
      interpreter == null ? nullptr : interpreter.value.toNativeUtf8();

  final code = execute(commandC, interpreterC);

  // cleanup
  malloc.free(commandC);
  if (interpreterC != nullptr) {
    malloc.free(interpreterC);
  }

  return code;
}
