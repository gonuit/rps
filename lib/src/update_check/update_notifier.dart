import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:rps/rps.dart';
import 'package:rps/src/update_check/pub_dev_api.dart';
import 'package:rps/src/update_check/update_check_result.dart';
import 'package:rps/src/update_check/update_checker.dart';
import 'package:rps/src/utils/rps_package.dart';

/// Displays a bordered update banner when a newer version is available.
class UpdateNotifier {
  final UpdateChecker _checker;
  final Console _console;
  final Duration _postAlertPause;

  /// Creates an [UpdateNotifier].
  UpdateNotifier({
    required UpdateChecker checker,
    required Console console,
    Duration postAlertPause = const Duration(seconds: 2),
  })  : _checker = checker,
        _console = console,
        _postAlertPause = postAlertPause;

  /// Creates an [UpdateNotifier] pre-configured for the given [package].
  factory UpdateNotifier.forPackage({
    required RpsPackage package,
    required Console console,
  }) {
    return UpdateNotifier(
      checker: UpdateChecker(
        currentVersion: package.version,
        packageName: package.name,
        api: PubDevApi(userAgent: '${package.name}/${package.version}'),
        config: package.config,
      ),
      console: console,
    );
  }

  /// Checks for updates and shows a banner if one is available.
  Future<void> notifyIfUpdateAvailable() async {
    try {
      final result = await _checker.check();
      if (result == null) return;
      _render(result);
      _checker.markAlertShown();
      await Future.delayed(_postAlertPause);
    } on SocketException {
      // Network unreachable.
    } on HttpException {
      // HTTP protocol error.
    } on http.ClientException {
      // DNS / connection refused.
    } on TimeoutException {
      // Network timeout from UpdateChecker.
    } on FormatException {
      // Malformed JSON or version string from pub.dev.
    } on PubDevApiException {
      // pub.dev returned a non-200.
    }
  }

  void _render(UpdateCheckResult result) {
    _console.writeBordered([
      'Update available ${gray(result.current.toString())} → ${green(result.latest.toString())}',
      'Run ${lightBlue('dart pub global activate rps')} to update',
    ]);
  }
}
