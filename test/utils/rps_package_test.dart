import 'package:rps/rps.dart';
import 'package:rps/src/utils/rps_package.dart';
import 'package:test/test.dart';

import '../mocks/fake_file_system.dart';

const _packagePubspec = '''
name: rps
version: 0.10.1
''';

void main() {
  group('RpsPackage', () {
    test('loads package from resolved path', () async {
      final fs = FakeFileSystem(
        resolvedPackagePath: '/pub-cache/rps',
        directories: {
          '/pub-cache/rps': ['/pub-cache/rps/pubspec.yaml'],
        },
        files: {
          '/pub-cache/rps/pubspec.yaml': _packagePubspec,
        },
      );

      final package = await RpsPackage.load(fs: fs);

      expect(package.name, equals('rps'));
      expect(package.version.toString(), equals('0.10.1'));
    });

    test('throws when package cannot be resolved', () async {
      final fs = FakeFileSystem(resolvedPackagePath: null);

      expect(
        () => RpsPackage.load(fs: fs),
        throwsA(isA<RpsException>()),
      );
    });
  });
}
