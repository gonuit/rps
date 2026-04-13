import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import 'package:rps/rps.dart';
import 'package:rps/src/models/interpreter.dart';
import 'package:rps/src/utils/file_system.dart';
import 'package:rps/src/utils/platform.dart' as rps;

/// Native FFI signature for the execute function.
typedef ExecuteNative = Int32 Function(
  Pointer<Utf8> command,
  Pointer<Utf8>? interpreter,
);

/// Dart-side FFI signature for the execute function.
typedef Execute = int Function(
  Pointer<Utf8> command,
  Pointer<Utf8>? interpreter,
);

/// Callback type for functions that execute a shell command.
typedef ExecuteFunction = Future<int> Function(
  String command,
);

/// Executes a shell [command] via the platform-specific native library.
Future<int> execute(
  String command, {
  bool verbose = false,
  Interpreter? interpreter,
  StringSink? out,
  required rps.Platform platform,
  required FileSystem fs,
}) async {
  final bindings = <Abi, String>{
    Abi.windowsX64: 'rps_x64.dll',
    Abi.linuxX64: 'librps_x64.so',
    Abi.linuxArm64: 'librps_aarch64.so',
    Abi.macosX64: 'librps.dylib',
    Abi.macosArm64: 'librps.dylib',
  };

  if (!platform.isWindows && interpreter is WindowsInterpreter) {
    throw RpsException(
      'The Windows interpreter cannot be used on ${platform.operatingSystem}.',
    );
  }
  if (!platform.isLinux &&
      !platform.isMacOS &&
      interpreter is UnixInterpreter) {
    throw RpsException(
      'The Unix interpreter cannot be used on ${platform.operatingSystem}.',
    );
  }

  if (verbose) {
    if (interpreter != null) {
      out?.writeln('Using interpreter: ${interpreter.value}');
    } else {
      out?.writeln('Using default interpreter');
    }
  }

  const rootLibrary = 'package:rps/rps.dart';
  final packagePath = await fs.resolvePackagePath(rootLibrary);
  if (packagePath == null) {
    throw RpsException('Cannot load the library.');
  }

  final abi = Abi.current();
  if (verbose) {
    out?.writeln('Running on platform: $abi');
  }

  String? libraryName = bindings[abi];

  if (verbose) {
    out?.writeln('Dynamic library file selected: $libraryName');
  }

  if (libraryName == null) {
    throw RpsException('Current platform ($abi) is currently not supported.');
  }

  final nativePath = path.join(packagePath, 'native');
  final libraryPath = path.join(nativePath, libraryName);

  if (verbose) {
    out?.writeln('Dynamic library path: $libraryPath');
  }

  final dylib = DynamicLibrary.open(libraryPath);
  final executeFn = dylib.lookupFunction<ExecuteNative, Execute>('execute');

  final commandC = command.toNativeUtf8();
  final interpreterC =
      interpreter == null ? nullptr : interpreter.value.toNativeUtf8();

  final code = executeFn(commandC, interpreterC);

  // cleanup
  malloc.free(commandC);
  if (interpreterC != nullptr) {
    malloc.free(interpreterC);
  }

  return code;
}
