import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:rps/rps.dart';
import 'package:rps/src/config/rps_config.dart';
import 'package:rps/src/update_check/clock.dart';
import 'package:rps/src/update_check/pub_dev_api.dart';
import 'package:rps/src/update_check/update_checker.dart';
import 'package:rps/src/update_check/update_notifier.dart';
import 'package:rps/src/utils/environment.dart';
import 'package:test/test.dart';

import '../mocks/fake_file_system.dart';
import '../mocks/stream_sink_controller.dart';

class _FixedClock implements Clock {
  @override
  DateTime now() => DateTime.utc(2026, 1, 1);
}

class _FailingWritesFileSystem extends FakeFileSystem {
  @override
  void writeFile(String path, String contents) {
    throw const FileSystemException('Read-only file system');
  }
}

class _Environment implements Environment {
  @override
  final bool isCI;
  @override
  final bool stdoutHasTerminal;
  @override
  final bool updateCheckDisabled;

  const _Environment({
    this.isCI = false,
    this.stdoutHasTerminal = true,
    this.updateCheckDisabled = false,
  });

  @override
  bool get hasTerminal => true;
  @override
  bool get stderrHasTerminal => true;
  @override
  bool get noColor => false;
  @override
  bool get assumeYes => false;
}

UpdateNotifier _notifier(
  StreamSinkController sink,
  MockClientHandler handler, {
  FakeFileSystem? fs,
}) {
  return UpdateNotifier(
    checker: UpdateChecker(
      currentVersion: Version.parse('1.0.0'),
      packageName: 'rps',
      api: PubDevApi(client: MockClient(handler)),
      config: RpsConfig.load('/pkg', fs: fs ?? FakeFileSystem()),
      clock: _FixedClock(),
    ),
    console: Console(sink: sink),
    postAlertPause: Duration.zero,
  );
}

void main() {
  group('shouldCheckForUpdates', () {
    test('is true on a terminal outside CI', () {
      expect(shouldCheckForUpdates(const _Environment()), isTrue);
    });

    test('is false in CI', () {
      expect(shouldCheckForUpdates(const _Environment(isCI: true)), isFalse);
    });

    test('is false when stdout is not a terminal', () {
      expect(
        shouldCheckForUpdates(const _Environment(stdoutHasTerminal: false)),
        isFalse,
      );
    });

    test('is false when disabled with the variable', () {
      expect(
        shouldCheckForUpdates(const _Environment(updateCheckDisabled: true)),
        isFalse,
      );
    });
  });

  group('UpdateNotifier', () {
    test('shows a banner when a newer version is available', () async {
      final sink = StreamSinkController();
      await _notifier(
        sink,
        (_) async => http.Response('{"latest":{"version":"2.0.0"}}', 200),
      ).notifyIfUpdateAvailable();

      expect(sink.plainLines.join('\n'), contains('1.0.0 → 2.0.0'));
    });

    test('stays silent when up to date', () async {
      final sink = StreamSinkController();
      await _notifier(
        sink,
        (_) async => http.Response('{"latest":{"version":"1.0.0"}}', 200),
      ).notifyIfUpdateAvailable();

      expect(sink.lines, isEmpty);
    });

    test('ignores TLS errors', () async {
      final sink = StreamSinkController();
      await _notifier(
        sink,
        (_) async => throw const HandshakeException('bad certificate'),
      ).notifyIfUpdateAvailable();

      expect(sink.lines, isEmpty);
    });

    test('ignores unexpected response shape', () async {
      final sink = StreamSinkController();
      await _notifier(
        sink,
        (_) async => http.Response('{"latest":null}', 200),
      ).notifyIfUpdateAvailable();

      expect(sink.lines, isEmpty);
    });

    test('ignores non-JSON error responses', () async {
      final sink = StreamSinkController();
      await _notifier(
        sink,
        (_) async => http.Response('<html>503</html>', 503),
      ).notifyIfUpdateAvailable();

      expect(sink.lines, isEmpty);
    });

    test('ignores config write failures', () async {
      final sink = StreamSinkController();
      await _notifier(
        sink,
        (_) async => http.Response('{"latest":{"version":"2.0.0"}}', 200),
        fs: _FailingWritesFileSystem(),
      ).notifyIfUpdateAvailable();
    });
  });
}
