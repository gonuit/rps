import 'package:rps/rps.dart';
import 'package:rps/src/cli/commands/script_selection.dart';
import 'package:test/test.dart';

import '../mocks/fake_executor.dart';
import '../mocks/fake_platform.dart';
import '../mocks/fake_prompt.dart';
import '../mocks/script_source.mock.dart';

const _scripts = r'''
scripts:
  hello: echo hello
  greet: echo ${0} and ${1}
  build:
    $args:
      flavor: dev
      target:
    $script: echo ${target} ${flavor}
  check:
    $steps:
      - echo a
      - echo b
  bad: echo ${1}
''';

Future<(FakeExecutor, FakePrompt, String)> _select(
  List<String> answers, {
  String scripts = _scripts,
}) async {
  final executor = FakeExecutor();
  final prompt = FakePrompt(answers);
  final output = StringBuffer();
  await ScriptSelectionCommand(
    runner: ScriptRunner(
      executor: executor,
      console: Console(sink: output, ansi: false),
      prompt: prompt,
      interactive: true,
    ),
    getScriptsSource: () => MockedScriptSource(scripts),
    platform: const FakePlatform(),
  ).run();
  return (executor, prompt, output.toString());
}

void main() {
  group('ScriptSelectionCommand', () {
    test('lists the scripts and runs the selected one', () async {
      final (executor, prompt, output) = await _select(['1']);

      expect(output, contains('Which scripts do you want to run?'));
      expect(output, contains('  1) hello (echo hello)\n'));
      expect(output, contains('  4) check (echo a && echo b)\n'));
      expect(prompt.questions, equals(['Select script:']));
      expect(executor.executions, equals(['echo hello']));
    });

    test('asks again until the answer is a listed number', () async {
      final (executor, prompt, _) = await _select(['', 'x', '0', '9', ' 4 ']);

      expect(prompt.questions, hasLength(5));
      expect(executor.executions, equals(['echo a', 'echo b']));
    });

    test('asks for positional arguments', () async {
      final (executor, prompt, _) = await _select(['2', 'you', 'me']);

      expect(
        prompt.questions.skip(1),
        equals([r'Provide argument ${0}:', r'Provide argument ${1}:']),
      );
      expect(executor.executions, equals(['echo you and me']));
    });

    test('asks for required named arguments only', () async {
      final (executor, prompt, _) = await _select(['3', 'apk']);

      expect(prompt.questions.last, equals('Provide argument --target:'));
      expect(prompt.questions, hasLength(2));
      expect(executor.executions, equals(['echo apk dev']));
    });

    test('reports the error of a selected script', () async {
      await expectLater(
        _select(['5']),
        throwsA(isA<RpsConfigException>()),
      );
    });

    test('fails when there are no scripts', () async {
      await expectLater(
        _select([], scripts: 'scripts: {}'),
        throwsA(isA<RpsException>()
            .having((e) => e.message, 'message', 'No scripts found.')),
      );
    });
  });
}
