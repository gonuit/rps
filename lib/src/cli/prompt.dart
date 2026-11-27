import 'dart:io' as io;

import 'package:rps/rps.dart';

/// Asks the user for a line of text.
abstract interface class Prompt {
  /// Shows [message] and returns the answer.
  ///
  /// Asks again until [validate] accepts the answer.
  String ask(String message, {bool Function(String answer)? validate});
}

/// A [Prompt] that reads from the terminal.
class TerminalPrompt implements Prompt {
  final Console _console;

  /// Creates a [TerminalPrompt] that shows questions on [console].
  const TerminalPrompt(Console console) : _console = console;

  @override
  String ask(String message, {bool Function(String answer)? validate}) {
    while (true) {
      _console.write('${bold(message)} ');
      final answer = io.stdin.readLineSync();
      if (answer == null) throw RpsException('No answer was given.');
      if (validate == null || validate(answer)) return answer;
    }
  }
}
