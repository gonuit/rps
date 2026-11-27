import 'package:rps/src/utils/environment.dart';

class FakeEnvironment implements Environment {
  @override
  final bool isCI;
  @override
  final bool hasTerminal;
  @override
  final bool stdoutHasTerminal;
  @override
  final bool stderrHasTerminal;
  @override
  final bool noColor;
  @override
  final bool updateCheckDisabled;
  @override
  final bool assumeYes;

  const FakeEnvironment({
    this.isCI = false,
    this.hasTerminal = true,
    this.stdoutHasTerminal = true,
    this.stderrHasTerminal = true,
    this.noColor = false,
    this.updateCheckDisabled = false,
    this.assumeYes = false,
  });
}
