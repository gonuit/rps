import 'package:rps/rps.dart';
import 'package:rps/src/config/rps_config.dart';
import 'package:rps/src/utils/rps_package.dart';

import 'fake_file_system.dart';

RpsPackage createFakeRpsPackage() {
  final fs = FakeFileSystem(
    files: {'/fake/pubspec.yaml': 'name: rps\nversion: 0.10.1\n'},
  );

  return RpsPackage(
    pubspec: Pubspec.load('/fake', fs: fs),
    config: RpsConfig.load('/fake', fs: fs),
  );
}
