import 'package:rps/rps.dart';

/// An abstract base class that must be implemented by all command classes.
abstract interface class Command {
  /// A brief description of the command.
  String get description;

  /// Command name. If null, the command is executed by default, no path.
  String? get name;

  /// An optional hint or usage information for the command.
  String? get tooltip;

  /// Determines if the command matches the provided list of arguments.
  ///
  /// Returns `true` if the command should be executed based on the [arguments].
  ///
  /// - Parameters:
  ///   - arguments: A list of command-line arguments.
  bool match(List<String> arguments);

  /// Executes the command using the given [console] and [arguments].
  ///
  /// - Parameters:
  ///   - console: The console instance for input/output operations.
  ///   - arguments: A list of command-line arguments.
  Future<void> run(Console console, List<String> arguments);
}
