import 'package:rps/rps.dart';
import 'package:rps/src/cli/cli.dart';
import 'package:rps/src/cli/cli_options/help.dart';
import 'package:rps/src/cli/cli_options/upgrade.dart';
import 'package:rps/src/cli/cli_options/version.dart';
import 'package:rps/src/cli/commands/list.dart';
import 'package:rps/src/cli/commands/script_selection.dart';
import 'package:rps/src/cli/exceptions/cli_exception.dart';
import 'package:rps/src/cli/executor.dart';
import 'package:rps/src/cli/global_flags.dart';
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
  final flags = GlobalFlags.parse(args);
  final color = !flags.noColor && !environment.noColor;
  final out = console.withAnsi(color && environment.stdoutHasTerminal);
  final errors = Console(
    sink: errorSink,
    ansi: color && environment.stderrHasTerminal,
  );
  try {
    final package = await RpsPackage.load(fs: fs);
    if (!environment.isCI) {
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

    executor ??= Executor(
      interpreter: config.getInterpreter(platform),
      platform: platform,
      fs: fs,
    );

    final help = HelpOption(console: out, package: package);
    final cli = Cli(
      package: package,
      console: out,
      commands: [
        if (!environment.isCI && environment.hasTerminal)
          ScriptSelectionCommand(
            getScriptsSource: getScriptSource,
            executor: executor,
            platform: platform,
          ),
        LsCommand(
          getScriptsSource: getScriptSource,
          platform: platform,
        ),
        RunCommand(
          getScriptsSource: getScriptSource,
          executor: executor,
          platform: platform,
        ),
      ],
      options: [
        help,
        const VersionOption(),
        UpgradeOption(platform: platform, fs: fs),
      ],
      fallback: environment.isCI ? null : help,
    );

    await cli.run(flags.arguments);
    return 0;
  } on RpsException catch (err) {
    errors.writeln('${boldRed('Error!')} ${err.message}');
    return 1;
  } on ScriptParserException catch (err) {
    errors.writeln('${boldRed('Error!')} ${err.message}');
    return 1;
  } on CliException catch (err) {
    errors.writeln('${boldRed('Error!')} ${err.message}');
    return err.exitCode;
  } catch (err) {
    errors.writeln('${boldRed('Error!')} $err');
    return 1;
  }
}
