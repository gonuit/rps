import 'package:rps/rps.dart';

abstract class Command {
  const Command();

  String get description;
  String get name;
  String? get tooltip;
  bool match(List<String> arguments);
  Future<void> run(Console console, List<String> arguments);
}
