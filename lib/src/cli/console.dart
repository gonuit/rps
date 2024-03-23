import 'dart:io';
import 'dart:math' as math;

String gray(String text) => '\x1B[30m$text\x1B[0m';
String red(String text) => '\x1B[31m$text\x1B[0m';
String green(String text) => '\x1B[32m$text\x1B[0m';
String yellow(String text) => '\x1B[33m$text\x1B[0m';
String blue(String text) => '\x1B[34m$text\x1B[0m';
String violet(String text) => '\x1B[35m$text\x1B[0m';
String lightBlue(String text) => '\x1B[36m$text\x1B[0m';
String white(String text) => '\x1B[37m$text\x1B[0m';
String bold(String text) => '\x1b[1m$text\x1b[0m';
String boldGreen(String text) => bold(green(text));
String boldRed(String text) => bold(red(text));
String boldBlue(String text) => bold(blue(text));

class BorderCharacters {
  final String topLeft;
  final String top;
  final String topRight;
  final String right;
  final String bottomRight;
  final String bottom;
  final String bottomLeft;
  final String left;
  final String empty;

  const BorderCharacters({
    required this.topLeft,
    required this.top,
    required this.topRight,
    required this.right,
    required this.bottomRight,
    required this.bottom,
    required this.bottomLeft,
    required this.left,
    required this.empty,
  });

  const BorderCharacters.basic()
      : topLeft = '┌',
        top = '─',
        topRight = '┐',
        right = '│',
        bottomRight = '┘',
        bottom = '─',
        bottomLeft = '└',
        left = '│',
        empty = ' ';

  String getTopBorder(int length) {
    return topLeft + top * length + topRight;
  }

  String getBottomBorder(int length) {
    return bottomLeft + bottom * length + bottomRight;
  }

  String getEmptyLine(int length) {
    return left + empty * length + right;
  }
}

String removeAnsiEscapeSequences(String input) {
  final ansiEscapePattern = RegExp(r'\x1B\[[0-9;]*[a-zA-Z]');
  return input.replaceAll(ansiEscapePattern, '');
}

enum Alignment { left, center, right }

class Console implements StringSink {
  final StringSink _sink;

  Console({required StringSink sink}) : _sink = sink;

  /// Function to remove ANSI escape sequences from a string

  /// Function to calculate the visible length of a string (excluding ANSI escape sequences)
  int visibleLength(String input) {
    return removeAnsiEscapeSequences(input).length;
  }

  void writeBordered(
    List<String> lines, {
    int horizontalPadding = 2,
    int verticalPadding = 1,
    BorderCharacters border = const BorderCharacters.basic(),
    Alignment alignment = Alignment.center,
  }) {
    if (horizontalPadding < 0) {
      throw ArgumentError.value(
        horizontalPadding,
        'horizontalPadding',
        'horizontalPadding cannot be lower than 0',
      );
    }
    if (verticalPadding < 0) {
      throw ArgumentError.value(
        verticalPadding,
        'verticalPadding',
        'verticalPadding cannot be lower than 0',
      );
    }

    final lineLengths = lines.map((line) => visibleLength(line)).toList();
    final maxLength = lineLengths.fold(0, (prevLength, length) => math.max(length, prevLength));
    final horizontalLength = maxLength + horizontalPadding * 2;

    writeln(border.getTopBorder(horizontalLength));
    for (int y = 0; y < verticalPadding; y++) {
      writeln(border.getEmptyLine(horizontalLength));
    }
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final length = lineLengths[i];

      final int paddingTotal;
      final int paddingStart;
      final int paddingEnd;

      switch (alignment) {
        case Alignment.left:
          paddingTotal = maxLength - length;
          paddingStart = horizontalPadding;
          paddingEnd = paddingTotal + horizontalPadding;
          break;
        case Alignment.center:
          paddingTotal = maxLength - length;
          final halfPadding = (paddingTotal ~/ 2);
          paddingStart = halfPadding + horizontalPadding;
          paddingEnd = (paddingTotal - halfPadding) + horizontalPadding;
          break;
        case Alignment.right:
          paddingTotal = maxLength - length;
          paddingStart = horizontalPadding + paddingTotal;
          paddingEnd = horizontalPadding;
          break;
      }
      writeln('${border.left}${border.empty * paddingStart}$line${border.empty * paddingEnd}${border.right}');
    }
    for (int y = 0; y < verticalPadding; y++) {
      writeln(border.getEmptyLine(horizontalLength));
    }
    writeln(border.getBottomBorder(horizontalLength));
  }

  @override
  void write(Object? object) {
    _sink.write(object);
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    _sink.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) {
    _sink.writeCharCode(charCode);
  }

  @override
  void writeln([Object? object = ""]) {
    _sink.writeln(object);
  }

  Future<void> flush() async {
    final sink = _sink;
    if (sink is IOSink) {
      await sink.flush();
    }
  }
}
