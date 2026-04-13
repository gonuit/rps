import 'package:rps/rps.dart';
import 'package:rps/src/cli/cli.dart';
import 'package:collection/collection.dart';

/// Base class for CLI options (e.g. --help, --version, --upgrade).
abstract class CliOption {
  /// Creates a [CliOption].
  const CliOption();

  /// Human-readable description of this option.
  String get description;

  /// Single-character shorthand (e.g. 'h' for -h).
  String? get short;

  /// Long-form name (e.g. 'help' for --help).
  String get name;

  /// Returns `true` if [arguments] match this option.
  bool match(List<String> arguments) {
    String? first = arguments.firstOrNull;
    if (first == null) return false;
    first = first.trim();
    return (short != null && first == '-$short') || first == '--$name';
  }

  /// Executes the option's action.
  Future<void> run(Cli cli, Console console, List<String> arguments);
}
