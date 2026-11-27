import 'package:args/args.dart';
import 'package:rps/rps.dart';

/// What rps is asked to do.
enum RpsAction {
  /// Print help.
  help,

  /// Print the rps version.
  version,

  /// Upgrade rps.
  upgrade,

  /// List scripts.
  list,

  /// Run a script.
  run,

  /// Let the user pick a script.
  select,
}

/// Parsed command line arguments of rps.
class RpsArguments {
  static const _help = 'help';
  static const _version = 'version';
  static const _upgrade = 'upgrade';
  static const _dryRun = 'dry-run';
  static const _noColor = 'no-color';
  static const _yes = 'yes';
  static const _all = 'all';
  static const _continue = 'continue';
  static const _json = 'json';
  static const _ls = 'ls';
  static const _run = 'run';

  static ArgParser _withFlags(ArgParser parser) => parser
    ..addFlag(
      _dryRun,
      abbr: 'n',
      negatable: false,
      help: 'Prints the commands of a script without running them.',
    )
    ..addFlag(
      _yes,
      abbr: 'y',
      negatable: false,
      help: 'Confirms scripts that ask for confirmation.',
    )
    ..addFlag(
      _all,
      abbr: 'a',
      negatable: false,
      help: 'Runs the script in every package of the pub workspace that '
          'defines it.',
    )
    ..addFlag(
      _continue,
      negatable: false,
      help: 'With --all, keeps going after the script fails in a package.',
    )
    ..addFlag(
      _noColor,
      negatable: false,
      help: 'Disables colored output.',
    );

  static final ArgParser _parser = _withFlags(
    ArgParser(allowTrailingOptions: false)
      ..addFlag(_help, abbr: 'h', negatable: false, help: 'Prints help.')
      ..addFlag(_version, negatable: false, help: 'Prints rps version.')
      ..addFlag(
        _upgrade,
        abbr: 'u',
        negatable: false,
        help: 'Updates rps to latest version.',
      ),
  )
    ..addCommand(
      _ls,
      ArgParser()
        ..addFlag(_json, negatable: false)
        ..addFlag(_noColor, negatable: false),
    )
    ..addCommand(_run, _withFlags(ArgParser(allowTrailingOptions: false)));

  /// Description of the options, for the help text.
  static String get optionsUsage =>
      _parser.usage.split('\n').map((line) => '  $line').join('\n');

  /// What rps is asked to do.
  final RpsAction action;

  /// Whether colored output is disabled.
  final bool noColor;

  /// Whether commands are printed instead of being run.
  final bool dryRun;

  /// Whether scripts that ask for confirmation are confirmed.
  final bool yes;

  /// Whether the script runs in every package of the workspace.
  final bool all;

  /// Whether a workspace run keeps going after a package fails.
  final bool continueOnError;

  /// Whether scripts are listed as JSON.
  final bool json;

  /// The script path followed by the arguments of the script.
  final List<String> script;

  /// Creates an [RpsArguments].
  const RpsArguments({
    required this.action,
    this.noColor = false,
    this.dryRun = false,
    this.yes = false,
    this.all = false,
    this.continueOnError = false,
    this.json = false,
    this.script = const [],
  });

  /// Whether [arguments] ask for output without colors.
  ///
  /// Never fails, so errors about the arguments can be printed accordingly.
  static bool disablesColor(List<String> arguments) {
    var commandSeen = false;
    for (final argument in arguments) {
      if (argument == '--$_noColor') return true;
      if (argument.startsWith('-')) continue;
      if (commandSeen || (argument != _ls && argument != _run)) return false;
      commandSeen = true;
    }
    return false;
  }

  /// Parses [arguments].
  factory RpsArguments.parse(List<String> arguments) {
    final ArgResults results;
    try {
      results = _parser.parse(arguments);
    } on FormatException catch (err) {
      throw RpsUsageException(
        err.message,
        hint: 'Run "rps --help" to see the available options.',
      );
    }

    final command = results.command;
    bool flag(String name) =>
        results.flag(name) ||
        (command != null &&
            command.options.contains(name) &&
            command.flag(name));

    final noColor = flag(_noColor);
    final dryRun = flag(_dryRun);
    final yes = flag(_yes);
    final all = flag(_all);
    final workspaceOptions = {_continue: flag(_continue)};
    for (final MapEntry(key: name, value: isSet) in workspaceOptions.entries) {
      if (isSet && !all) {
        throw RpsUsageException(
          'The --$name option works only with --$_all.',
          hint: 'Use it as "rps --$_all --$name <script>".',
        );
      }
    }

    RpsArguments build(RpsAction action, {List<String> script = const []}) {
      if (all && (action == RpsAction.select || action == RpsAction.list)) {
        throw RpsUsageException(
          'The --$_all option needs the name of a script.',
          hint: 'Use it as "rps --$_all <script>".',
        );
      }
      return RpsArguments(
        action: action,
        all: all,
        continueOnError: workspaceOptions[_continue]!,
        noColor: noColor,
        dryRun: dryRun,
        yes: yes,
        json: command?.name == _ls && command!.flag(_json),
        script: script,
      );
    }

    if (results.flag(_help)) return build(RpsAction.help);
    if (results.flag(_version)) return build(RpsAction.version);
    if (results.flag(_upgrade)) return build(RpsAction.upgrade);
    if (command?.name == _ls) return build(RpsAction.list);
    if (command?.name == _run) {
      return build(RpsAction.run, script: [_run, ...command!.rest]);
    }
    if (results.rest.isEmpty) return build(RpsAction.select);
    return build(RpsAction.run, script: results.rest);
  }
}
