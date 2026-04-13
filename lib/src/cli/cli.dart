import 'package:collection/collection.dart';
import 'package:rps/rps.dart';
import 'package:rps/src/cli/cli_options/cli_option.dart';
import 'package:rps/src/cli/commands/command.dart';
import 'package:rps/src/cli/exceptions/cli_exception.dart';
import 'package:rps/src/utils/rps_package.dart';

/// The main CLI entry point that routes arguments to commands and options.
class Cli {
  /// Metadata about the rps package itself.
  final RpsPackage package;

  /// Console used for output.
  final Console console;

  /// Registered sub-commands.
  final List<Command> commands;

  /// Registered CLI options (flags like --help, --version).
  final List<CliOption> options;

  /// Option to run when no command or option matches.
  final CliOption? fallback;

  /// Creates a new [Cli] instance.
  Cli({
    required this.package,
    required this.console,
    required this.commands,
    required this.options,
    required this.fallback,
  });

  /// Parses [arguments] and dispatches to the matching option or command.
  Future<void> run(List<String> arguments) async {
    try {
      final option =
          options.firstWhereOrNull((option) => option.match(arguments));
      if (option != null) {
        return option.run(this, console, arguments);
      }
      final command =
          commands.firstWhereOrNull((command) => command.match(arguments));
      if (command != null) {
        return command.run(console, arguments);
      }

      if (fallback != null) {
        return fallback!.run(this, console, arguments);
      }
      throw CliException('No command has been matched.');
    } catch (_) {
      await console.flush();
      rethrow;
    }
  }
}
