import 'package:rps/rps.dart';

class FakePrompt implements Prompt {
  FakePrompt([List<String> answers = const []]) : _answers = [...answers];

  final List<String> _answers;
  final List<String> questions = [];

  @override
  String ask(String message, {bool Function(String answer)? validate}) {
    while (true) {
      questions.add(message);
      if (_answers.isEmpty) throw StateError('Unexpected question: $message');
      final answer = _answers.removeAt(0);
      if (validate == null || validate(answer)) return answer;
    }
  }
}
