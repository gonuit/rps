import 'package:rps/rps.dart';
import 'package:rps/src/cli/arguments.dart';
import 'package:rps/src/cli/cli_options/help.dart';
import 'package:rps/src/cli/cli_options/upgrade.dart';
import 'package:rps/src/cli/cli_options/version.dart';
import 'package:rps/src/cli/commands/list.dart';
import 'package:rps/src/cli/commands/script_selection.dart';
import 'package:rps/src/cli/executor.dart';
import 'package:rps/src/models/rps_yaml_data.dart';
import 'package:rps/src/update_check/clock.dart';
import 'package:rps/src/update_check/update_notifier.dart';
import 'package:rps/src/utils/environment.dart';
import 'package:rps/src/utils/file_system.dart';
import 'package:rps/src/utils/platform.dart';
import 'package:rps/src/utils/rps_package.dart';

/// Runs the rps CLI with the given [args] and dependencies.
/// Returns an exit code (0 for success).
Future<int> runCli(
  List<String> args, {
  required Console console,
  required StringSink errorSink,
  required Environment environment,
  required Platform platform,
  required FileSystem fs,
  required Clock clock,
  Executor? executor,
}) async {
  final color = !RpsArguments.disablesColor(args) && !environment.noColor;
  final out = console.withAnsi(color && environment.stdoutHasTerminal);
  final errors = Console(
    sink: errorSink,
    ansi: color && environment.stderrHasTerminal,
  );
  try {
    final arguments = RpsArguments.parse(args);
    final package = await RpsPackage.load(fs: fs);
    if (shouldCheckForUpdates(environment)) {
      await UpdateNotifier.forPackage(
        package: package,
        console: out,
        clock: clock,
      ).notifyIfUpdateAvailable();
    }

    final cur = fs.currentDirectoryPath;
    final RpsYaml? rpsYaml =
        RpsYaml.exists(cur, fs: fs) ? RpsYaml.load(cur, fs: fs) : null;
    final config = rpsYaml?.data ?? const RpsYamlData();

    ScriptsSource getScriptSource() {
      if (rpsYaml != null && rpsYaml.hasScripts) {
        return rpsYaml;
      } else {
        return Pubspec.load(cur, fs: fs);
      }
    }

    final shell = Shell.of(config.getInterpreter(platform), platform);
    final runExecutor = executor ?? Executor(shell: shell);

    switch (arguments.action) {
      case RpsAction.help:
        printHelp(out, package);
      case RpsAction.version:
        printVersion(out, package);
      case RpsAction.upgrade:
        await upgrade(out, platform);
      case RpsAction.list:
        await LsCommand(
          getScriptsSource: getScriptSource,
          platform: platform,
        ).run(out, json: arguments.json);
      case RpsAction.run:
        await RunCommand(
          getScriptsSource: getScriptSource,
          executor: runExecutor,
          dryRun: arguments.dryRun,
          platform: platform,
        ).run(out, arguments.script);
      case RpsAction.select:
        if (environment.isCI) {
          throw RpsUsageException('No command has been matched.');
        } else if (environment.hasTerminal) {
          await ScriptSelectionCommand(
            getScriptsSource: getScriptSource,
            executor: runExecutor,
            dryRun: arguments.dryRun,
            platform: platform,
          ).run(out);
        } else {
          printHelp(out, package);
        }
    }
    return 0;
  } on RpsException catch (err) {
    errors.writeln('${boldRed('Error!')} ${err.message}');
    if (err is RpsUsageException) {
      errors.writeln(err.hint);
    }
    return err.exitCode;
  } catch (err) {
    errors.writeln('${boldRed('Error!')} $err');
    return ExitCodes.error;
  } finally {
    await out.flush();
  }
}
