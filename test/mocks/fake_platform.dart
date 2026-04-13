import 'package:rps/src/utils/platform.dart';

class FakePlatform implements Platform {
  @override
  final bool isWindows;
  @override
  final bool isMacOS;
  @override
  final bool isLinux;
  @override
  final String operatingSystem;

  const FakePlatform({
    this.isWindows = false,
    this.isMacOS = true,
    this.isLinux = false,
    this.operatingSystem = 'macos',
  });

  const FakePlatform.linux()
      : isWindows = false,
        isMacOS = false,
        isLinux = true,
        operatingSystem = 'linux';

  const FakePlatform.windows()
      : isWindows = true,
        isMacOS = false,
        isLinux = false,
        operatingSystem = 'windows';
}
