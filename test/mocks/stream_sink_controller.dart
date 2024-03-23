import 'dart:convert';

import 'package:rps/rps.dart';

class StreamSinkController implements StringSink {
  StreamSinkController();

  List<String> get lines => const LineSplitter().convert(_writes.join(''));
  List<String> get plainLines => lines.map(removeAnsiEscapeSequences).toList();
  final _writes = <String>[];

  @override
  void write(Object? obj) {
    _writes.add(obj.toString());
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    _writes.add(objects.join(separator));
  }

  @override
  void writeln([Object? obj = ""]) {
    _writes.add('$obj\n');
  }

  @override
  void writeCharCode(int charCode) {
    _writes.add(String.fromCharCode(charCode));
  }

  void clear() {
    _writes.clear();
  }
}
