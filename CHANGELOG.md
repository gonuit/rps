## 0.13.0
- Added `$steps`: a script can run several commands and references one after another and stops at the first one that fails.
- Added `$parallel`: a script can run commands at the same time, with every line of the output labeled with its command.
  - When one command fails, the others are stopped.
- Added named arguments. A script declares them with `$args`, uses them as `${name}` and gets them as `--name value` or `--name=value`.
- Added `$env` and `$envFile` to set environment variables for a script or a group of scripts.
- Added `$cwd` to run a script or a group of scripts in another directory.
- Added `$confirm`: a script can ask for confirmation before it runs. `--yes` (`-y`) or `RPS_YES=1` confirms it, and without a terminal the script does not run without them.
- `rps ls` and `rps ls --json` describe the new keys: `steps`, `parallel`, `cwd`, `env`, `envFiles`, `confirm` and named arguments.
- A key that starts with `$` and is not known to rps, such as a misspelled `$descripton`, is now reported as an error instead of being ignored or treated as a script.
- A reference can be used more than once in the hooks of one script.
- `rps ls | head` and similar no longer end with a stack trace when the reader closes the output.

## 0.12.0
- Colors are used only when the output is a terminal. They are also disabled by the `NO_COLOR` environment variable, `TERM=dumb` and the new `--no-color` flag.
  - Output piped to a file or another program no longer contains color codes.
- The update notice and its one second pause appear only when the output is a terminal. Set `RPS_NO_UPDATE_CHECK=1` to turn the update check off.
- Added `rps ls --json`, which lists scripts with their path, command, description, positional arguments and errors.
- Added `--dry-run` (`-n`), which prints the commands of a script with its hooks without running them.
- Exit codes are now documented and stable: `64` for a missing script or a missing positional argument, `78` for a configuration error. The exit code of a failed script is passed through as before.
  - These errors previously ended with exit code `1`.
- Errors about a missing script suggest running `rps ls`.
- Added the "Using rps with AI agents" section to the README.
- Scripts are now run without a native library, so rps works on every desktop platform supported by the Dart SDK, including Windows on Arm64.
- Pressing Ctrl-C lets the running script handle the interruption and clean up. Previously the script was killed immediately.
  - rps now exits with the exit code of the interrupted script, usually `130`, instead of `137`.
- A termination signal sent to rps is passed on to the running script.
- A missing interpreter is reported with a clear error.
- **Breaking**: removed the `cmd` interpreter. Scripts on Windows always run in PowerShell, and `interpreter: cmd` in `rps.yaml` is now a configuration error.
- Fixed empty arguments being dropped when passed to a script on Windows.
- An unknown option before the script name, such as `rps --foo build`, is now an error instead of being treated as a script name.
  - `rps ls` also rejects unknown options instead of ignoring them.
- The help text lists all options and shows the usage.
- **Breaking** for users of the Dart API: removed `ExecuteNative`, `Execute`, `ShellSyntax`, `quoteArgument`, `ScriptParserException` and `RunCommand.match`. `execute` and `CommandExecuted.compile` take a `Shell`.

## 0.11.0
- Skip update check and interactive selection in CI environments.
  - `CI=false` and `CI=0` are not treated as a CI environment.
- Fixed gray text invisible on dark terminals.
- Fixed quoting of arguments passed to scripts: spaces, apostrophes, empty arguments and shell characters such as `&`, `;` or `*` are passed as-is.
  - Arguments are now always literal, so `$VAR` inside an argument is no longer expanded by the shell.
- Running a script that does not exist now fails instead of exiting with success, also for nested paths and references.
- Scripts nested under a `run` key can be selected from the menu and run with `rps run <name>`.
- Problems with the update check (network, proxy, read-only package directory) no longer break or delay rps.
- Calling `rps` without a terminal prints help instead of crashing.
- An empty `rps.yaml` no longer causes an error.

## 0.10.1
- Added dartdoc comments and package example.
- Enabled stricter linting rules.

## 0.10.0
- Calling `rps` will now display a list of all commands and allow you to select them.
- Switched from `cmd` to `powershell` on Windows platform.
  - It allows multiline scripts to be executed correctly, resolves [#16](https://github.com/gonuit/rps/issues/16).
- `rps ls` no longer lists `$before` / `$after` hook entries.
- Child script exit codes are now reported correctly on macOS and Linux, and propagated back to the parent shell (`rps fail` where `fail: exit 7` now exits `7`).
## 0.9.1
- Used static linking of the CRT library on Windows instead of dynamic - solves Windows problems when the CRT library was not present.
## 0.9.0
- Added support for an external script file (`rps.yaml`), thanks to [@masreplay](https://github.com/masreplay) in [#24](https://github.com/gonuit/rps/pull/24).
## 0.8.2
- Fix arguments serialization. escape backslashes, single and double quotes for shell safety and enclose in quotes if necessary: contains spaces or quotes.
## 0.8.1
- Added support for Linux Arm64 (aarch64) architecture.
- Improved Abi handling
## 0.8.0
### BREAKING CHANGES
- Support for positional arguments: `${0}`, `${1}` ...
- To use references use `rps` instead of `$` prefix.
### Additional changes
- Added list command: `rps ls`
  - Lists all available commands
- Added upgrade command: `rps -u` / `rps --upgrade`
- Improved help command `rps -h` / `rps --help`
- Updated readme documentation.
## 0.7.0

### BREAKING CHANGES

- A special `$script` key has been introduced with a neat 💪 platform recognition feature.

  Do you work on multiple platforms? Need to use many different commands and always forget which one to use? This is what you've been waiting for!

  ```yaml
  scripts:
    where-am-i:
      $script:
        $windows: echo "You are on Windows!"
        $linux: echo "You are on Linux!"
        $macos: echo "You are on MacOs!"
        $default: echo "You are on... something else?"
  ```

  ```
  user@MacBook-Pro Desktop % rps where-am-i
  > where-am-i
  $ echo "You are on MacOs!"

  You are on MacOs!

  user@MacBook-Pro Desktop %
  ```

  This can be useful for commands like `rm -rf`, which in Windows.... `rd /s /q`, you know what I mean, it can be helpful, right?

- Added support for script references. From now on it is possible to call another rps command directly from a defined script.

  ```yaml
  scripts:
    app:
      clean: flutter clean
    clean: $app clean
    c: $clean
    clear: $c
    delete: $clear
  ```

  This is just a simple proxy example, but you can also use it in `$before` and `$after` hooks to chain multiple scripts together.

- ⚠️ The `before-` and `after-` hooks has been removed. Instead use the `$before` and `$after` keys. This will help keep hook scripts grouped in a project with multiple scripts defined.

  ```yaml
  scripts:
    hooks:
      $before: echo "before"
      $script: echo "script"
      $after: echo "after"
  ```

  Execute by calling the `rps hooks`.

  It is also possible to link multiple scripts together!

  ```yaml
  scripts:
    get: flutter pub get
    test:
      $before: $get
      $script: flutter test
    build:
      $before: $test
      $script: flutter build apk
  ```

  You don't have to worry about cyclic references, RPS will keep track of them and notify you in case of a problem.

## 0.6.5

- Update dependencies
- Longer description in pubspec.yaml
- pedantic (deprecated) replaced by flutter_lints

## 0.6.4

- Fixed readme example

## 0.6.3

- Minor bug fixes and improvements. 🚧

## 0.6.2

- Exposed executables.

## 0.6.1

- Minor bug fixes and improvements. 🚧
- Added colorful logs. 🎨
- Shared with the world via Github and pub.dev! 🌎

## 0.6.0

- Added optional `before-` and `after-` hooks support.

## 0.5.1

- A `--version` flag has been added.

## 0.5.0

- Move towards native implementation.
  - Added native support for linux (x86_64).

## 0.4.0

- Move towards native implementation.
  - Added native support for windows (x86_64).

## 0.3.1

- Move towards native implementation.
  - Added native support for macos (arm64).

## 0.3.0

- Move towards native implementation.
  - Added native support for macos (x86_64).

## 0.2.0

- Added basic logs.
- Added two-way communication with the child process through dart `Process`.

## 0.1.0

- Initial version.
