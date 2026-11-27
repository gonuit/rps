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

Future<StreamSinkController> _ls(List<String> arguments) async {
  final sink = StreamSinkController();
  await LsCommand(
    getScriptsSource: () => MockedScriptSource(_scripts),
    platform: const FakePlatform(),
  ).run(Console(sink: sink, ansi: false), arguments);
  return sink;
}

void main() {
  group('LsCommand', () {
    test('prints a readable list by default', () async {
      final sink = await _ls(['ls']);
      expect(sink.lines.first, equals('Commands:'));
      expect(sink.lines, contains('  hello (echo hello)'));
    });

    test('prints JSON with --json', () async {
      final sink = await _ls(['ls', '--json']);
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
          },
          {
            'path': 'greet',
            'command': r'echo ${0} ${1}',
            'description': null,
            'arguments': [
              {'name': r'${0}', 'index': 0},
              {'name': r'${1}', 'index': 1},
            ],
            'errors': [],
          },
          {
            'path': 'bad',
            'command': r'echo ${1}',
            'description': null,
            'arguments': [],
            'errors': [
              r'The script defines unused positional argument(s): ${0}',
            ],
          },
          {
            'path': 'build apk',
            'command': 'echo apk',
            'description': null,
            'arguments': [],
            'errors': [],
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
          },
        ]),
      );
    });

    test('prints an empty list as JSON when there are no scripts', () async {
      final sink = StreamSinkController();
      await LsCommand(
        getScriptsSource: () => MockedScriptSource('scripts: {}'),
        platform: const FakePlatform(),
      ).run(Console(sink: sink), ['ls', '--json']);

      expect(jsonDecode(sink.lines.join('\n')), equals({'scripts': []}));
    });
  });
}
