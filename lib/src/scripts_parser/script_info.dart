import 'package:rps/rps.dart';

/// A script as shown in lists: where it is, what it runs and what it needs.
class ScriptInfo {
  /// Keys that lead to the script, for example `[build, android]`.
  final List<String> keys;

  /// The definition of the script.
  final Script script;

  /// The reasons the script cannot be run, if any.
  final List<String> errors;

  /// Positional arguments used by the script, sorted by index.
  final List<PositionalArgument> commandArguments;

  /// Directory the script runs in, relative to the project, if set.
  final String? workingDirectory;

  /// Environment variables set for the script.
  final Map<String, String> environment;

  /// Env files loaded for the script, later files win.
  final List<String> envFiles;

  /// The question the script asks before it runs, if any.
  final String? confirmation;

  ScriptInfo._({
    required this.keys,
    required this.script,
    required this.errors,
    required this.commandArguments,
    required this.workingDirectory,
    required this.environment,
    required this.envFiles,
    required this.confirmation,
  });

  /// Creates a [ScriptInfo], parsing positional arguments of the [script].
  factory ScriptInfo({
    required List<String> keys,
    required Script script,
    List<String> errors = const [],
    String? workingDirectory,
    Map<String, String> environment = const {},
    List<String> envFiles = const [],
    String? confirmation,
  }) {
    final allErrors = [...errors];
    var commandArguments = const <PositionalArgument>[];
    try {
      commandArguments = PositionalArgument.parse(script.command);
    } on RpsException catch (err) {
      allErrors.add(err.message);
    }
    return ScriptInfo._(
      keys: keys,
      script: script,
      errors: allErrors,
      commandArguments: commandArguments,
      workingDirectory: workingDirectory,
      environment: environment,
      envFiles: envFiles,
      confirmation: confirmation,
    );
  }

  /// What is typed after `rps` to run the script.
  String get path => keys.join(' ');

  /// The command for the current platform.
  String get command => script.command;

  /// Optional human-readable description.
  String? get description => script.description;

  /// Named arguments declared by the script.
  List<ScriptArgument> get declaredArguments => script.args;

  /// Commands the script runs one after another, if it is a sequence.
  List<String>? get steps => script.steps;

  /// Commands the script runs at the same time, if it is a parallel group.
  List<String>? get parallel => script.parallel;

  /// The command on one line.
  String get summary =>
      steps?.join(' && ') ??
      parallel?.join(' & ') ??
      command.replaceAll('\n', ' ').trim();

  /// Returns a combined error message, or null if there are no errors.
  String? get errorMessage => errors.isEmpty ? null : errors.join('\n');
}
