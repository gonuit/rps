/// Flags of rps itself, given before the script name.
class GlobalFlags {
  /// The `--no-color` flag.
  static const noColorFlag = '--no-color';

  /// The `--dry-run` flag and its short form.
  static const dryRunFlags = ['--dry-run', '-n'];

  /// Flags as shown in help, with their descriptions.
  static const descriptions = {
    '  -n, --dry-run': 'Prints the commands of a script without running them.',
    '      --no-color': 'Disables colored output.',
  };

  /// Whether colored output is disabled.
  final bool noColor;

  /// Whether commands are printed instead of being run.
  final bool dryRun;

  /// The arguments left after the flags are removed.
  final List<String> arguments;

  /// Creates a [GlobalFlags].
  const GlobalFlags({
    required this.noColor,
    required this.dryRun,
    required this.arguments,
  });

  /// Extracts the flags that precede the script name from [arguments].
  factory GlobalFlags.parse(List<String> arguments) {
    var noColor = false;
    var dryRun = false;
    var commandSeen = false;
    final rest = <String>[];
    var index = 0;
    for (; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == noColorFlag) {
        noColor = true;
      } else if (dryRunFlags.contains(argument)) {
        dryRun = true;
      } else if (!commandSeen && (argument == 'run' || argument == 'ls')) {
        commandSeen = true;
        rest.add(argument);
      } else {
        break;
      }
    }
    rest.addAll(arguments.skip(index));
    return GlobalFlags(noColor: noColor, dryRun: dryRun, arguments: rest);
  }
}
