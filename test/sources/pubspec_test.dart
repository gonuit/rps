import 'package:rps/rps.dart';
import 'package:test/test.dart';

import '../mocks/fake_file_system.dart';

const _validPubspec = '''
name: my_app
version: 1.0.0
scripts:
  test: echo "running tests"
''';

void main() {
  group('Pubspec', () {
    test('loads and parses pubspec.yaml', () {
      final fs = FakeFileSystem(
        files: {'/project/pubspec.yaml': _validPubspec},
      );

      final pubspec = Pubspec.load('/project', fs: fs);

      expect(pubspec.packageName, equals('my_app'));
      expect(pubspec.packageVersion, equals('1.0.0'));
      expect(pubspec.directoryPath, equals('/project'));
    });

    test('getScripts returns scripts map', () {
      final fs = FakeFileSystem(
        files: {'/project/pubspec.yaml': _validPubspec},
      );

      final pubspec = Pubspec.load('/project', fs: fs);
      final scripts = pubspec.getScripts();

      expect(scripts['test'], equals('echo "running tests"'));
    });

    test('throws when pubspec.yaml not found', () {
      final fs = FakeFileSystem();

      expect(
        () => Pubspec.load('/project', fs: fs),
        throwsA(isA<RpsException>()),
      );
    });

    test('throws when scripts field is missing', () {
      final fs = FakeFileSystem(
        files: {'/project/pubspec.yaml': 'name: my_app\nversion: 1.0.0\n'},
      );

      final pubspec = Pubspec.load('/project', fs: fs);
      expect(
        () => pubspec.getScripts(),
        throwsA(isA<RpsException>()),
      );
    });

    test('throws when pubspec.yaml is invalid', () {
      final fs = FakeFileSystem(
        files: {'/project/pubspec.yaml': ': invalid: yaml: ['},
      );

      expect(
        () => Pubspec.load('/project', fs: fs),
        throwsA(isA<RpsException>()),
      );
    });
  });
}
