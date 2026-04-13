import 'package:rps/rps.dart';
import 'package:test/test.dart';

import '../mocks/fake_file_system.dart';

const _validRpsYaml = '''
scripts:
  build: echo "building"
  test: echo "testing"
''';

void main() {
  group('RpsYaml', () {
    test('exists returns true when file is present', () {
      final fs = FakeFileSystem(
        files: {'/project/rps.yaml': ''},
      );

      expect(RpsYaml.exists('/project', fs: fs), isTrue);
    });

    test('exists returns false when file is absent', () {
      final fs = FakeFileSystem();

      expect(RpsYaml.exists('/project', fs: fs), isFalse);
    });

    test('loads and parses rps.yaml', () {
      final fs = FakeFileSystem(
        files: {'/project/rps.yaml': _validRpsYaml},
      );

      final rpsYaml = RpsYaml.load('/project', fs: fs);

      expect(rpsYaml.hasScripts, isTrue);
      expect(rpsYaml.directoryPath, equals('/project'));
    });

    test('getScripts returns scripts map', () {
      final fs = FakeFileSystem(
        files: {'/project/rps.yaml': _validRpsYaml},
      );

      final rpsYaml = RpsYaml.load('/project', fs: fs);
      final scripts = rpsYaml.getScripts();

      expect(scripts['build'], equals('echo "building"'));
    });

    test('throws when rps.yaml not found', () {
      final fs = FakeFileSystem();

      expect(
        () => RpsYaml.load('/project', fs: fs),
        throwsA(isA<RpsException>()),
      );
    });

    test('throws when scripts field is missing', () {
      final fs = FakeFileSystem(
        files: {'/project/rps.yaml': 'windows:\n  interpreter: powershell\n'},
      );

      final rpsYaml = RpsYaml.load('/project', fs: fs);
      expect(
        () => rpsYaml.getScripts(),
        throwsA(isA<RpsException>()),
      );
    });

    test('throws when rps.yaml is invalid', () {
      final fs = FakeFileSystem(
        files: {'/project/rps.yaml': 'not a yaml map'},
      );

      expect(
        () => RpsYaml.load('/project', fs: fs),
        throwsA(isA<RpsException>()),
      );
    });
  });
}
