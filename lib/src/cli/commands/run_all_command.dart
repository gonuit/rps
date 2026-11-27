import 'package:rps/rps.dart';
import 'package:rps/src/models/rps_yaml_data.dart';

/// Runs a script in every package of a pub workspace that defines it.
class RunAllCommand {
  /// Runs the commands of the scripts.
  final ScriptRunner runner;

  static const _interrupted = 130;

  /// Whether the packages after a failed one still run.
  final bool continueOnError;

  /// Whether the packages run at the same time.
  final bool parallel;

  final Workspace _workspace;
  final FileSystem _fs;
  final Platform _platform;

  /// Creates a [RunAllCommand].
  RunAllCommand({
    required this.runner,
    this.continueOnError = false,
    this.parallel = false,
    required Workspace workspace,
    required FileSystem fs,
    required Platform platform,
  })  : _workspace = workspace,
        _fs = fs,
        _platform = platform;

  List<ExecutionEvent>? _resolve(
    WorkspacePackage package,
    List<String> arguments,
  ) {
    final rpsYaml = RpsYaml.exists(package.path, fs: _fs)
        ? RpsYaml.load(package.path, fs: _fs)
        : null;
    final ScriptsSource source;
    if (rpsYaml != null && rpsYaml.hasScripts) {
      source = rpsYaml;
    } else if (package.pubspec.parsed['scripts'] != null) {
      source = package.pubspec;
    } else {
      return null;
    }

    final config = rpsYaml?.data ?? const RpsYamlData();
    final parser = ScriptsParser(
      source: source,
      platform: _platform,
      settings: ExecutionSettings(
        baseDirectory: package.path,
        shell: Shell.of(config.getInterpreter(_platform), _platform),
      ),
    );
    final path = RunCommand.scriptPath(parser, arguments);
    if (!parser.defines(path)) return null;
    return parser.getCommandsToExecute(path);
  }

  List<(WorkspacePackage, List<ExecutionEvent>)> _plan(List<String> arguments) {
    final plans = <(WorkspacePackage, List<ExecutionEvent>)>[];
    for (final package in _workspace.packages) {
      try {
        final events = _resolve(package, arguments);
        if (events == null || events.isEmpty) continue;
        runner.validate(events);
        plans.add((package, events));
      } on RpsUsageException catch (error) {
        throw RpsUsageException(
          'In the package "${package.name}": ${error.message}',
          hint: error.hint,
        );
      } on RpsConfigException catch (error) {
        throw RpsConfigException(
          'In the package "${package.name}": ${error.message}',
        );
      }
    }
    return plans;
  }

  /// Runs the script that [arguments] point to in every package that has it.
  Future<void> run(List<String> arguments) async {
    final script = arguments.join(' ');
    final plans = _plan(arguments);
    if (plans.isEmpty) {
      throw RpsUsageException(
        'No package of the workspace defines the script "$script".',
        hint: 'Run "rps ls" in a package to see its scripts.',
      );
    }

    runner.confirm([for (final (_, events) in plans) ...events]);

    final console = runner.console;
    if (parallel) {
      await runner.run(
        [
          ParallelExecuted(
            context: arguments.fold(
              Context.root(),
              (context, key) => context.next(key),
            ),
            branches: [
              for (final (package, events) in plans)
                ParallelBranch(label: package.name, events: events),
            ],
            failFast: !continueOnError,
          ),
        ],
        confirm: false,
      );
      _summary(script, plans.length);
      return;
    }

    final failed = <String>[];
    var notRun = const <String>[];
    int? exitCode;
    for (final (index, (package, events)) in plans.indexed) {
      console.writeln(
        '${boldGreen('▶')} ${bold(package.name)} '
        '${gray('(${package.relativePath})')}\n',
      );
      try {
        await runner.run(events, confirm: false);
      } on RpsException catch (error) {
        runner.errors.writeln('${boldRed('Error!')} ${error.message}');
        failed.add(package.name);
        exitCode ??= error.exitCode;
        // An interrupted run does not go on to the next package.
        if (continueOnError && error.exitCode != _interrupted) continue;
        notRun = [for (final (rest, _) in plans.skip(index + 1)) rest.name];
        break;
      }
    }

    if (exitCode != null) {
      throw ScriptFailedException(
        [
          'The script "$script" failed in ${failed.length} of '
              '${plans.length} package(s): ${failed.join(', ')}.',
          if (notRun.isNotEmpty) 'Not run: ${notRun.join(', ')}.',
        ].join(' '),
        exitCode: exitCode,
      );
    }
    _summary(script, plans.length);
  }

  void _summary(String script, int count) {
    if (runner.dryRun) return;
    runner.console.writeln(
      '${boldGreen('✓')} Ran "$script" in $count package(s).',
    );
  }
}
