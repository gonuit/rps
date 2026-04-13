import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

/// Manages reading and writing the rps.config file.
class RpsConfig {
  final File _file;

  /// The current configuration data.
  RpsConfigData get data => _data;
  RpsConfigData _data;

  RpsConfig._({
    required File file,
    required RpsConfigData data,
  })  : _data = data,
        _file = file;

  /// Loads the config from [directory], creating a default one if missing.
  factory RpsConfig.load(Directory directory) {
    final configFile = File(p.join(directory.path, 'rps.config'));

    RpsConfig createInitial() {
      final config = RpsConfigData.initial();
      configFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(config.toJson()),
        flush: true,
      );
      return RpsConfig._(file: configFile, data: config);
    }

    if (!configFile.existsSync()) {
      return createInitial();
    }

    try {
      final data = configFile.readAsStringSync();
      final config = RpsConfigData.fromJson(jsonDecode(data));
      return RpsConfig._(file: configFile, data: config);
    } on Exception catch (err) {
      stdout.write('Cannot read configuration. Fallback to default.\n$err');
      return createInitial();
    }
  }

  /// Persists [data] to disk and updates the in-memory state.
  void update(RpsConfigData data) {
    _file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(data.toJson()),
      flush: true,
    );
    _data = data;
  }
}

/// Holds the serialisable configuration values.
class RpsConfigData {
  /// When the last update check was performed.
  final DateTime? updateCheckedAt;

  /// The latest known version on pub.dev.
  final Version? latestVersion;

  /// When the last update alert was shown to the user.
  final DateTime? lastUpdateAlertAt;

  /// Creates a [RpsConfigData].
  RpsConfigData({
    required this.updateCheckedAt,
    required this.latestVersion,
    required this.lastUpdateAlertAt,
  });

  /// Returns a config with all fields set to null.
  factory RpsConfigData.initial() => RpsConfigData(
        updateCheckedAt: null,
        latestVersion: null,
        lastUpdateAlertAt: null,
      );

  /// Returns a copy with the given fields replaced.
  RpsConfigData copyWith({
    DateTime? updateCheckedAt,
    Version? latestVersion,
    DateTime? lastUpdateAlertAt,
  }) =>
      RpsConfigData(
        updateCheckedAt: updateCheckedAt ?? this.updateCheckedAt,
        latestVersion: latestVersion ?? this.latestVersion,
        lastUpdateAlertAt: lastUpdateAlertAt ?? this.lastUpdateAlertAt,
      );

  /// Deserialises from a JSON map.
  static RpsConfigData fromJson(Map<String, dynamic> json) {
    return RpsConfigData(
      updateCheckedAt: json['updateCheckedAt'] != null
          ? DateTime.parse(json['updateCheckedAt'])
          : null,
      latestVersion: json['latestVersion'] != null
          ? Version.parse(json['latestVersion'])
          : null,
      lastUpdateAlertAt: json['lastUpdateAlertAt'] != null
          ? DateTime.parse(json['lastUpdateAlertAt'])
          : null,
    );
  }

  /// Serialises to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'updateCheckedAt': updateCheckedAt?.toUtc().toIso8601String(),
      'lastUpdateAlertAt': lastUpdateAlertAt?.toUtc().toIso8601String(),
      'latestVersion': latestVersion?.toString(),
    };
  }
}
