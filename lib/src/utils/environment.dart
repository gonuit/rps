import 'dart:io';

/// Provides information about the runtime environment.
abstract interface class Environment {
  /// Whether the process is running in a CI environment.
  bool get isCI;

  /// Whether stdin is attached to a terminal, so the user can be prompted.
  bool get hasTerminal;

  /// Whether stdout is attached to a terminal.
  bool get stdoutHasTerminal;

  /// Whether stderr is attached to a terminal.
  bool get stderrHasTerminal;

  /// Whether colors are disabled with `NO_COLOR` or `TERM=dumb`.
  bool get noColor;

  /// Whether the update check is disabled with `RPS_NO_UPDATE_CHECK`.
  bool get updateCheckDisabled;

  /// Whether scripts are confirmed without asking, with `RPS_YES`.
  bool get assumeYes;
}

/// Default [Environment] backed by platform environment variables.
class SystemEnvironment implements Environment {
  /// Creates a [SystemEnvironment].
  const SystemEnvironment();

  @override
  bool get hasTerminal => stdin.hasTerminal;

  @override
  bool get stdoutHasTerminal => stdout.hasTerminal;

  @override
  bool get stderrHasTerminal => stderr.hasTerminal;

  @override
  bool get noColor =>
      isNoColorValue(Platform.environment['NO_COLOR']) ||
      Platform.environment['TERM'] == 'dumb';

  @override
  bool get updateCheckDisabled =>
      isCIValue(Platform.environment['RPS_NO_UPDATE_CHECK']);

  @override
  bool get assumeYes => isCIValue(Platform.environment['RPS_YES']);

  @override
  bool get isCI => isCIValue(Platform.environment['CI']);

  /// Whether [value] of an on/off variable such as `CI` turns it on.
  static bool isCIValue(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    return normalized.isNotEmpty && normalized != 'false' && normalized != '0';
  }

  /// Whether [value] of the `NO_COLOR` variable disables colors.
  static bool isNoColorValue(String? value) =>
      value != null && value.isNotEmpty;
}
