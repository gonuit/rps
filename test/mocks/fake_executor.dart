import 'package:rps/rps.dart';

class FakeExecutor extends Executor {
  FakeExecutor({this.exitCode = 0, List<String>? executions})
      : executions = executions ?? [],
        super(shell: const PosixShell());

  final int exitCode;
  final List<String> executions;
  final List<String?> workingDirectories = [];
  final List<Map<String, String>?> environments = [];

  @override
  Future<int> execute(
    String command, {
    Map<String, String>? environment,
    String? workingDirectory,
    CommandOutput? output,
  }) async {
    executions.add(command);
    workingDirectories.add(workingDirectory);
    environments.add(environment);
    return exitCode;
  }
}
