import 'dart:io';
import 'dart:math' as math;

/// Wraps [text] in gray ANSI escape codes.
String gray(String text) => '\x1B[90m$text\x1B[0m';

/// Wraps [text] in red ANSI escape codes.
String red(String text) => '\x1B[31m$text\x1B[0m';

/// Wraps [text] in green ANSI escape codes.
String green(String text) => '\x1B[32m$text\x1B[0m';

/// Wraps [text] in yellow ANSI escape codes.
String yellow(String text) => '\x1B[33m$text\x1B[0m';

/// Wraps [text] in blue ANSI escape codes.
String blue(String text) => '\x1B[34m$text\x1B[0m';

/// Wraps [text] in violet ANSI escape codes.
String violet(String text) => '\x1B[35m$text\x1B[0m';

/// Wraps [text] in light blue ANSI escape codes.
String lightBlue(String text) => '\x1B[36m$text\x1B[0m';

/// Wraps [text] in white ANSI escape codes.
String white(String text) => '\x1B[37m$text\x1B[0m';

/// Wraps [text] in bold ANSI escape codes.
String bold(String text) => '\x1b[1m$text\x1b[0m';

/// Returns bold green [text].
String boldGreen(String text) => bold(green(text));

/// Returns bold red [text].
String boldRed(String text) => bold(red(text));

/// Returns bold blue [text].
String boldBlue(String text) => bold(blue(text));

/// Characters used to draw box borders in the console.
class BorderCharacters {
  /// Top-left corner character.
  final String topLeft;

  /// Top edge character.
  final String top;

  /// Top-right corner character.
  final String topRight;

  /// Right edge character.
  final String right;

  /// Bottom-right corner character.
  final String bottomRight;

  /// Bottom edge character.
  final String bottom;

  /// Bottom-left corner character.
  final String bottomLeft;

  /// Left edge character.
  final String left;

  /// Empty fill character.
  final String empty;

  /// Creates a [BorderCharacters] with custom characters.
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

  /// Creates a [BorderCharacters] with standard Unicode box-drawing characters.
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

  /// Returns a top border string of the given [length].
  String getTopBorder(int length) {
    return topLeft + top * length + topRight;
  }

  /// Returns a bottom border string of the given [length].
  String getBottomBorder(int length) {
    return bottomLeft + bottom * length + bottomRight;
  }

  /// Returns an empty line of the given [length].
  String getEmptyLine(int length) {
    return left + empty * length + right;
  }
}

/// Strips ANSI escape sequences from [input].
String removeAnsiEscapeSequences(String input) {
  final ansiEscapePattern = RegExp(r'\x1B\[[0-9;]*[a-zA-Z]');
  return input.replaceAll(ansiEscapePattern, '');
}

/// Text alignment within a fixed-width column.
enum Alignment {
  /// Align text to the left.
  left,

  /// Center the text.
  center,

  /// Align text to the right.
  right,
}

/// A [StringSink] wrapper that adds bordered output and ANSI utilities.
class Console implements StringSink {
  final StringSink _sink;

  /// Creates a [Console] backed by the given [sink].
  Console({required StringSink sink}) : _sink = sink;

  /// Returns the visible length of [input] (excluding ANSI escape sequences).
  int visibleLength(String input) {
    return removeAnsiEscapeSequences(input).length;
  }

  /// Writes [lines] surrounded by a box border.
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
    final maxLength = lineLengths.fold(
        0, (prevLength, length) => math.max(length, prevLength));
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
      writeln(
          '${border.left}${border.empty * paddingStart}$line${border.empty * paddingEnd}${border.right}');
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
  void writeAll(Iterable objects, [String separator = '']) {
    _sink.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) {
    _sink.writeCharCode(charCode);
  }

  @override
  void writeln([Object? object = '']) {
    _sink.writeln(object);
  }

  /// Flushes the underlying sink if it is an [IOSink].
  Future<void> flush() async {
    final sink = _sink;
    if (sink is IOSink) {
      await sink.flush();
    }
  }
}
