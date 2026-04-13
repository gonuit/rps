import 'dart:convert';

import 'package:pub_semver/pub_semver.dart';
import 'package:rps/src/config/rps_config.dart';
import 'package:test/test.dart';

import '../mocks/fake_file_system.dart';

void main() {
  group('RpsConfig', () {
    test('creates initial config when file does not exist', () {
      final fs = FakeFileSystem(
        files: {},
        directories: {},
      );

      final config = RpsConfig.load('/pkg', fs: fs);

      expect(config.data.updateCheckedAt, isNull);
      expect(config.data.latestVersion, isNull);
      expect(config.data.lastUpdateAlertAt, isNull);
      expect(fs.writtenFiles, contains('/pkg/rps.config'));
    });

    test('loads existing config from file', () {
      final data = RpsConfigData(
        updateCheckedAt: DateTime.utc(2026, 1, 1),
        latestVersion: Version.parse('1.0.0'),
        lastUpdateAlertAt: DateTime.utc(2026, 1, 2),
      );
      final fs = FakeFileSystem(
        files: {
          '/pkg/rps.config':
              const JsonEncoder.withIndent('  ').convert(data.toJson()),
        },
      );

      final config = RpsConfig.load('/pkg', fs: fs);

      expect(config.data.latestVersion, equals(Version.parse('1.0.0')));
      expect(config.data.updateCheckedAt, equals(DateTime.utc(2026, 1, 1)));
    });

    test('falls back to initial when file is corrupt', () {
      final fs = FakeFileSystem(
        files: {'/pkg/rps.config': 'not json'},
      );
      final out = StringBuffer();

      final config = RpsConfig.load('/pkg', fs: fs, out: out);

      expect(config.data.latestVersion, isNull);
      expect(out.toString(), contains('Cannot read configuration'));
    });

    test('update persists data', () {
      final fs = FakeFileSystem(files: {});
      final config = RpsConfig.load('/pkg', fs: fs);

      final newData = config.data.copyWith(
        latestVersion: Version.parse('2.0.0'),
      );
      config.update(newData);

      expect(config.data.latestVersion, equals(Version.parse('2.0.0')));
      expect(fs.files['/pkg/rps.config'], contains('2.0.0'));
    });
  });

  group('RpsConfigData', () {
    test('initial has all nulls', () {
      final data = RpsConfigData.initial();
      expect(data.updateCheckedAt, isNull);
      expect(data.latestVersion, isNull);
      expect(data.lastUpdateAlertAt, isNull);
    });

    test('copyWith replaces fields', () {
      final data = RpsConfigData.initial();
      final updated = data.copyWith(
        latestVersion: Version.parse('1.0.0'),
      );
      expect(updated.latestVersion, equals(Version.parse('1.0.0')));
      expect(updated.updateCheckedAt, isNull);
    });

    test('toJson and fromJson round-trip', () {
      final original = RpsConfigData(
        updateCheckedAt: DateTime.utc(2026, 3, 15),
        latestVersion: Version.parse('1.2.3'),
        lastUpdateAlertAt: DateTime.utc(2026, 3, 16),
      );
      final json = original.toJson();
      final restored = RpsConfigData.fromJson(json);

      expect(restored.updateCheckedAt, equals(original.updateCheckedAt));
      expect(restored.latestVersion, equals(original.latestVersion));
      expect(restored.lastUpdateAlertAt, equals(original.lastUpdateAlertAt));
    });
  });
}
