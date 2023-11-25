abstract class Command {
  String get description;
  String get name;
  Future<void> run(List<String> arguments);
}
