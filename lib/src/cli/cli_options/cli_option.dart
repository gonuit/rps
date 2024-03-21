import 'package:rps/rps.dart';
import 'package:rps/src/cli/cli.dart';
import 'package:collection/collection.dart';

abstract class CliOption {
  const CliOption();

  String get description;
  String? get short;
  String get name;

  bool match(List<String> arguments) {
    String? first = arguments.firstOrNull;
    if (first == null) return false;
    first = first.trim();
    return (short != null && first == '-$short') || first == '--$name';
  }

  Future<void> run(Cli cli, Console console, List<String> arguments);
}
