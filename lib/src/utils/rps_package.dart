import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:http_api/http_api.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:rps/rps.dart';
import 'package:path/path.dart' as p;
import 'package:rps/src/utils/date_utils.dart';

class PubDevApiException {
  final int? statusCode;
  final String? message;

  PubDevApiException(this.statusCode, [this.message]);

  factory PubDevApiException.fromResponse(
    Response response,
  ) {
    if (response.bodyBytes != null) {
      final data = jsonDecode(response.body);
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        return PubDevApiException(
          response.statusCode!,
          error['message'],
        );
      }
    }

    return PubDevApiException(response.statusCode);
  }
}

class PubDevApi extends BaseApi {
  PubDevApi() : super(Uri.parse('https://pub.dev/api'));

  Future<String> getLastVersion(String packageName) async {
    final response = await get('/packages/$packageName');

    if (response.ok) {
      final data = jsonDecode(response.body);
      return data['latest']['version'];
    } else {
      throw PubDevApiException.fromResponse(response);
    }
  }
}

class PackageVersions {
  final Version latest;
  final Version current;

  PackageVersions({
    required this.latest,
    required this.current,
  });

  bool get hasUpdate => latest > current;
}

class RpsConfig {
  final File _file;
  RpsConfigData get data => _data;
  RpsConfigData _data;

  RpsConfig._({
    required File file,
    required RpsConfigData data,
  })  : _data = data,
        _file = file;

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
    } else {
      try {
        final data = configFile.readAsStringSync();
        final config = RpsConfigData.fromJson(jsonDecode(data));
        return RpsConfig._(file: configFile, data: config);
      } on Exception catch (err) {
        stdout.write("Cannot read configuration. Fallback to default.\n$err");
        return createInitial();
      }
    }
  }

  void update(RpsConfigData data) {
    _file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(data.toJson()),
      flush: true,
    );
    _data = data;
  }
}

class RpsConfigData {
  final DateTime? updateCheckedAt;
  final Version? latestVersion;

  RpsConfigData({
    required this.updateCheckedAt,
    required this.latestVersion,
  });

  factory RpsConfigData.initial() => RpsConfigData(
        updateCheckedAt: null,
        latestVersion: null,
      );

  RpsConfigData copyWith({
    DateTime? updateCheckedAt,
    Version? latestVersion,
  }) =>
      RpsConfigData(
        updateCheckedAt: updateCheckedAt ?? this.updateCheckedAt,
        latestVersion: latestVersion ?? this.latestVersion,
      );

  static RpsConfigData fromJson(Map<String, dynamic> json) {
    return RpsConfigData(
      updateCheckedAt: json['updateCheckedAt'] != null ? DateTime.parse(json['updateCheckedAt']) : null,
      latestVersion: json['latestVersion'] != null ? Version.parse(json['latestVersion']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'updateCheckedAt': updateCheckedAt?.toIso8601String(),
      'latestVersion': latestVersion.toString(),
    };
  }
}

class RpsPackage {
  final Pubspec _pubspec;
  final PubDevApi _api;
  final RpsConfig _config;

  Version get version => Version.parse(_pubspec.packageVersion);

  RpsPackage({
    required Pubspec pubspec,
    required PubDevApi api,
    required RpsConfig lockFile,
  })  : _pubspec = pubspec,
        _api = api,
        _config = lockFile;

  static Future<RpsPackage> load() async {
    Future<Directory> getPackageDirectory() async {
      const rootLibrary = 'package:rps/rps.dart';
      final uri = await Isolate.resolvePackageUri(Uri.parse(rootLibrary));
      if (uri == null) {
        print('Library cannot be loaded.');
        exit(1);
      }

      final root = uri.resolve('..');
      return Directory.fromUri(root);
    }

    final directory = await getPackageDirectory();

    return RpsPackage(
      pubspec: Pubspec.load(directory),
      api: PubDevApi(),
      lockFile: RpsConfig.load(directory),
    );
  }

  Future<Version> getLatestPackageVersion() async {
    final cachedVersion = _config.data.latestVersion;
    final cacheDate = _config.data.updateCheckedAt;
    final now = DateTime.now();

    // Return cached if valid
    if (cachedVersion != null && cacheDate != null && cacheDate.isSameDay(now)) {
      return cachedVersion;
    }

    final version = await _api.getLastVersion('rps');
    final parsedVersion = Version.parse(version);
    _config.update(_config.data.copyWith(
      updateCheckedAt: DateTime.now(),
      latestVersion: parsedVersion,
    ));
    return parsedVersion;
  }

  Future<PackageVersions> getVersions() async {
    final latest = await getLatestPackageVersion().timeout(const Duration(milliseconds: 300));

    return PackageVersions(
      latest: latest,
      current: version,
    );
  }

  void dispose() {
    _api.dispose();
  }
}
