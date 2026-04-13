import 'package:rps/rps.dart';
import 'package:test/test.dart';

import '../mocks/stream_sink_controller.dart';

void main() {
  late StreamSinkController sink;
  late Console console;

  setUp(() {
    sink = StreamSinkController();
    console = Console(sink: sink);
  });

  group('Console', () {
    test('write appends to sink', () {
      console.write('hello');
      expect(sink.lines.join(), contains('hello'));
    });

    test('writeln appends line', () {
      console.writeln('line');
      expect(sink.plainLines, contains('line'));
    });

    test('writeAll joins with separator', () {
      console.writeAll(['a', 'b', 'c'], ', ');
      expect(sink.lines.join(), contains('a, b, c'));
    });

    test('writeCharCode writes character', () {
      console.writeCharCode(65); // 'A'
      expect(sink.lines.join(), contains('A'));
    });

    test('flush does not throw for non-IOSink', () async {
      await console.flush();
    });

    test('visibleLength strips ANSI codes', () {
      final length = console.visibleLength(bold(red('hello')));
      expect(length, equals(5));
    });
  });

  group('Console.writeBordered', () {
    test('draws box around lines', () {
      console.writeBordered(['hello']);
      final output = sink.plainLines.join('\n');
      expect(output, contains('┌'));
      expect(output, contains('└'));
      expect(output, contains('hello'));
    });

    test('supports left alignment', () {
      console.writeBordered(
        ['hi', 'hello'],
        alignment: Alignment.left,
      );
      final output = sink.plainLines.join('\n');
      expect(output, contains('hi'));
      expect(output, contains('hello'));
    });

    test('supports right alignment', () {
      console.writeBordered(
        ['hi', 'hello'],
        alignment: Alignment.right,
      );
      final output = sink.plainLines.join('\n');
      expect(output, contains('hi'));
    });

    test('throws on negative horizontal padding', () {
      expect(
        () => console.writeBordered(['x'], horizontalPadding: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on negative vertical padding', () {
      expect(
        () => console.writeBordered(['x'], verticalPadding: -1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('BorderCharacters', () {
    test('basic creates default box characters', () {
      const border = BorderCharacters.basic();
      expect(border.topLeft, equals('┌'));
      expect(border.bottomRight, equals('┘'));
    });

    test('getTopBorder returns correct string', () {
      const border = BorderCharacters.basic();
      expect(border.getTopBorder(3), equals('┌───┐'));
    });

    test('getBottomBorder returns correct string', () {
      const border = BorderCharacters.basic();
      expect(border.getBottomBorder(3), equals('└───┘'));
    });

    test('getEmptyLine returns correct string', () {
      const border = BorderCharacters.basic();
      expect(border.getEmptyLine(3), equals('│   │'));
    });
  });

  group('ANSI helpers', () {
    test('removeAnsiEscapeSequences strips codes', () {
      expect(removeAnsiEscapeSequences(red('test')), equals('test'));
      expect(removeAnsiEscapeSequences(bold('test')), equals('test'));
      expect(removeAnsiEscapeSequences(boldGreen('test')), equals('test'));
    });

    test('color functions wrap text', () {
      expect(gray('x'), contains('x'));
      expect(red('x'), contains('x'));
      expect(green('x'), contains('x'));
      expect(yellow('x'), contains('x'));
      expect(blue('x'), contains('x'));
      expect(violet('x'), contains('x'));
      expect(lightBlue('x'), contains('x'));
      expect(white('x'), contains('x'));
      expect(bold('x'), contains('x'));
      expect(boldGreen('x'), contains('x'));
      expect(boldRed('x'), contains('x'));
      expect(boldBlue('x'), contains('x'));
    });
  });
}
