import 'dart:convert';

import 'package:rps/rps.dart';
import 'package:rps/src/cli/commands/list.dart';
import 'package:test/test.dart';

import '../mocks/fake_platform.dart';
import '../mocks/script_source.mock.dart';
import '../mocks/stream_sink_controller.dart';

const _scripts = r'''
scripts:
  hello:
    $script: echo hello
    $description: Says hello
  greet: echo ${0} ${1}
  bad: echo ${1}
  build:
    $before: echo before
    apk: echo apk
  plat:
    $script:
      $nope: echo nope
''';

const _noKeys = {
  'steps': null,
  'parallel': null,
  'cwd': null,
  'env': <String>[],
  'envFiles': <String>[],
  'confirm': null,
};

const _positional = {'option': null, 'required': true, 'default': null};

const _keyScripts = r'''
scripts:
  $envFile: .env
  $env: {APP_ENV: dev}
  release:
    $description: Releases the app
    $cwd: packages/app
    $env: {TOKEN: secret-value}
    $confirm: Release to production?
    $args:
      flavor: prod
      target:
    $steps:
      - flutter build ${target} --flavor ${flavor} ${0}
      - rps upload
  verify:
    $parallel:
      - dart analyze
      - dart test
''';

Future<StreamSinkController> _ls({
  bool json = false,
  String scripts = _scripts,
}) async {
  final sink = StreamSinkController();
  await LsCommand(
    getScriptsSource: () => MockedScriptSource(scripts),
    platform: const FakePlatform(),
  ).run(Console(sink: sink, ansi: false), json: json);
  return sink;
}

void main() {
  group('LsCommand', () {
    test('prints a readable list by default', () async {
      final sink = await _ls();
      expect(sink.lines.first, equals('Commands:'));
      expect(sink.lines, contains('  hello (echo hello)'));
    });

    test('prints JSON with --json', () async {
      final sink = await _ls(json: true);
      final scripts = (jsonDecode(sink.lines.join('\n')) as Map)['scripts'];

      expect(
        scripts,
        equals([
          {
            'path': 'hello',
            'command': 'echo hello',
            'description': 'Says hello',
            'arguments': [],
            'errors': [],
            ..._noKeys,
          },
          {
            'path': 'greet',
            'command': r'echo ${0} ${1}',
            'description': null,
            'arguments': [
              {'name': r'${0}', 'index': 0, ..._positional},
              {'name': r'${1}', 'index': 1, ..._positional},
            ],
            'errors': [],
            ..._noKeys,
          },
          {
            'path': 'bad',
            'command': r'echo ${1}',
            'description': null,
            'arguments': [],
            'errors': [
              r'The script defines unused positional argument(s): ${0}',
            ],
            ..._noKeys,
          },
          {
            'path': 'build apk',
            'command': 'echo apk',
            'description': null,
            'arguments': [],
            'errors': [],
            ..._noKeys,
          },
          {
            'path': 'plat',
            'command': '-',
            'description': null,
            'arguments': [],
            'errors': [
              'No platform script key for the command: "plat". '
                  'Consider adding the key for the current platform: '
                  r'"$macos" or the default script key: "$default".',
            ],
            ..._noKeys,
          },
        ]),
      );
    });

    test('describes the script keys in JSON', () async {
      final sink = await _ls(json: true, scripts: _keyScripts);
      final scripts = (jsonDecode(sink.lines.join('\n')) as Map)['scripts'];

      expect(
        scripts,
        equals([
          {
            'path': 'release',
            'command': r'flutter build ${target} --flavor ${flavor} ${0}'
                '\nrps upload',
            'description': 'Releases the app',
            'arguments': [
              {'name': r'${0}', 'index': 0, ..._positional},
              {
                'name': 'flavor',
                'index': null,
                'option': '--flavor',
                'required': false,
                'default': 'prod',
              },
              {
                'name': 'target',
                'index': null,
                'option': '--target',
                'required': true,
                'default': null,
              },
            ],
            'steps': [
              r'flutter build ${target} --flavor ${flavor} ${0}',
              'rps upload',
            ],
            'parallel': null,
            'cwd': 'packages/app',
            'env': ['APP_ENV', 'TOKEN'],
            'envFiles': ['.env'],
            'confirm': 'Release to production?',
            'errors': [],
          },
          {
            'path': 'verify',
            'command': 'dart analyze\ndart test',
            'description': null,
            'arguments': [],
            'steps': null,
            'parallel': ['dart analyze', 'dart test'],
            'cwd': null,
            'env': ['APP_ENV'],
            'envFiles': ['.env'],
            'confirm': null,
            'errors': [],
          },
        ]),
      );
      expect(sink.lines.join('\n'), isNot(contains('secret-value')));
    });

    test('describes the script keys in the readable list', () async {
      final sink = await _ls(scripts: _keyScripts);

      expect(
        sink.lines,
        containsAllInOrder([
          r'  release (flutter build ${target} --flavor ${flavor} ${0} '
              '&& rps upload)',
          '    Releases the app',
          '    Arguments: [--flavor=prod] --target',
          '    Runs in: packages/app',
          '    Asks for confirmation.',
          '  verify (dart analyze & dart test)',
        ]),
      );
      expect(sink.lines.join('\n'), isNot(contains('secret-value')));
    });

    test('prints an empty list as JSON when there are no scripts', () async {
      final sink = StreamSinkController();
      await LsCommand(
        getScriptsSource: () => MockedScriptSource('scripts: {}'),
        platform: const FakePlatform(),
      ).run(Console(sink: sink), json: true);

      expect(jsonDecode(sink.lines.join('\n')), equals({'scripts': []}));
    });
  });
}
