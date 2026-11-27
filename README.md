# Run Pubspec Script (RPS)

RPS is a dart script manager that allows you to define and use scripts from the _pubspec.yaml_ file.


## Features
<!-- no toc -->
- [🔦 Listing commands](#-listing-commands)
- [🪆 Nesting](#-nesting)
- [🔗 References](#-references)
- [🪝 Hooks](#-hooks)
- [💻 Platform specific scripts](#-platform-specific-scripts)
- [🎯 Positional arguments](#-positional-arguments)
- [🏷 Named arguments](#-named-arguments)
- [🪜 Steps](#-steps)
- [🧵 Parallel scripts](#-parallel-scripts)
- [🌱 Environment variables](#-environment-variables)
- [📂 Working directory](#-working-directory)
- [✋ Confirmation](#-confirmation)
- [📝 External scripts file](#-external-scripts-file)
- [🛠 CLI options](#-cli-options)
- [🚦 Exit codes](#-exit-codes)
- [🤖 Using rps with AI agents](#-using-rps-with-ai-agents)

## Quick start 🚀

1. Install this package.
    ```bash
    dart pub global activate rps
    ```
2. Define scripts inside the `pubspec.yaml` or create an [`rps.yaml` file](#-external-scripts-file).
      ```yaml
      scripts:
        gen: flutter pub run build_runner build --delete-conflicting-outputs
      ```
3. Use your custom command.
    ```bash
    rps gen
    # you can also provide additional arguments
    rps gen --verbose
    ```
4. Save time and become a power user! 😈
    
    Less time typing long commands more time watching funny cats. 🐈

# Features

## 🔦 Listing commands

Not sure what command to choose? Add a description to your scripts:

```yaml
scripts:
  build:
    web: 
      $script: flutter build web --flavor production -t lib/main.dart
      $description: Builds a web application
    android:
      $script: flutter build apk --flavor production -t lib/main.dart
      $description: Builds an Android app
```

Then type `rps ls` to preview all of them:

```
Commands:
  build web (flutter build web --flavor production -t lib/main.dart)
    Builds a web application
  build android (flutter build apk --flavor production -t lib/main.dart)
    Builds an Android app
```

For tools and scripts, `rps ls --json` prints the same list as JSON:

```json
{
  "scripts": [
    {
      "path": "build web",
      "command": "flutter build web --flavor production -t lib/main.dart",
      "description": "Builds a web application",
      "arguments": [],
      "steps": null,
      "parallel": null,
      "cwd": null,
      "env": [],
      "envFiles": [],
      "confirm": null,
      "errors": []
    }
  ]
}
```

- `path` is what you type after `rps`.
- `command` is the command for the current platform.
- `description` is `null` when the script has none.
- `arguments` lists the [positional](#-positional-arguments) and [named](#-named-arguments) arguments the script expects. A positional one has an `index`, a named one has an `option` such as `--flavor`, and both have `required` and `default`.
- `steps` and `parallel` list the commands of a script that uses [`$steps`](#-steps) or [`$parallel`](#-parallel-scripts), otherwise they are `null`.
- `cwd` is the [working directory](#-working-directory), `env` lists the names of the [environment variables](#-environment-variables) set for the script, and `envFiles` lists its env files.
- `confirm` is the question the script asks before it runs, or `null`.
- `errors` lists problems in the script definition. A script with errors cannot be run.

## 🪆 Nesting

Nest your commands to group them contextually and make them easier to understand.

```yaml
scripts:
  build:
    web: flutter build web --flavor production -t lib/main.dart
    android:
      apk: flutter build apk --flavor production -t lib/main.dart
      appbundle: flutter build appbundle --flavor production -t lib/main.dart
    ios:
      ipa: flutter build ipa --flavor production -t lib/main.dart
      ios: flutter build ios --flavor production -t lib/main.dart
```

Use with ease 😏

```
rps build android apk
```

## 🔗 References

Sometimes you may want to create a command alias (eg. a shorter version of it) or simply pass the execution of a hook to another command. This is where references come to the rescue! ⛑

References are defined as a scripts that must begin with `rps` prefix.

```yaml
scripts:
  generator:
    build: flutter pub run build_runner build --delete-conflicting-outputs
    watch: flutter pub run build_runner watch --delete-conflicting-outputs
  # short aliases:
  gb: rps generator build
  # They will not trigger an additional rps process.
  gw: rps generator watch
```

References can also be used with `$before` and `$after` hooks.

## 🪝 Hooks


To enable hooks define the `$before` and/or `$after` keys for your script command.

```yaml
scripts:
  hello:
    $before: echo "hello before" # executed before the $script
    $script: echo "hello script"
    $after: echo "hello after" # executed after $script
```

All hooks will be executed in the specified order when calling the `rps hello` command.

You can also combine multiple scripts using references!

```yaml
scripts:
  get: flutter pub get
  test:
    # equivalent of "rps get"
    $before: rps get
    $script: flutter test
  build:
    # equivalent of "rps test"
    $before: rps test
    $script: flutter build apk
```

You can also nest hooks to provide an easy-to-read workflow for all grouped commands!

```yaml
# Order when executing: "rps generator build"
scripts:
  generator:
    $before: dart pub get # 1.
    $after: dart analyze # 5.
    build:
      $before: echo "Building JSON models..." # 2.
      $script: dart pub run build_runner build # 3.
      $after: echo "JSON models built successfully..." # 4.
```

You don't have to worry about cyclic references 🔄, RPS will keep track of them and notify you in case of a problem 😏.

## 💻 Platform specific scripts

Do you work on multiple platforms? Need to use many different commands and always forget which one to use? This is what you've been waiting for! 🛠

Just use one command on all supported platforms 💪.

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
```

This can be useful for commands like `rm -rf`, which in Windows.... `rd /s /q`, you know what I mean, it can be helpful, right?

## 🎯 Positional arguments

Arguments can be passed by adding them to the end of the command － simple, but sometimes it is useful to give them in a specific place, here positional arguments come to the rescue.

Positional arguments are defined as numbers in parentheses: `${0}`, `${1}`, `${2}` and so on....

For example, you can use the following command to specify the target to be built.

```yaml
scripts:
  build: flutter build ${0} -t lib/main.dart --release
```

Now just run `rps build apk`.  

You can still add trailing arguments, such as `rps build apk --flavor funny` what will execute the following command `flutter build apk -t lib/main.dart --release --flavor funny`.

A few rules to keep in mind:
- Indices must be contiguous starting from `${0}` — using `${0}` and `${2}` without `${1}` will error.
- The same index can be reused in one command (e.g. `echo ${0} ${0}`).
- Hooks (`$before` / `$after`) **do not** support positional arguments.
- Trailing arguments are passed to the script literally, so characters such as spaces, quotes, `&` or `$` are not interpreted by the shell.

## 🏷 Named arguments

Positional arguments get hard to read when a script takes more than one or two. Declare named arguments with `$args` and use them as `${name}`:

```yaml
scripts:
  build:
    $args:
      flavor: dev   # default value
      target:       # no default, so it is required
    $script: flutter build ${target} --flavor ${flavor}
```

```bash
rps build --target apk
rps build --target apk --flavor prod
rps build --target=apk --flavor=prod --release
```

- Only declared names are filled in, so shell variables such as `${HOME}` keep working.
- Arguments that are not declared, like `--release` above, are passed to the script as before. Everything after `--` is passed to the script too.
- Values are quoted for the shell. Do not put a placeholder inside quotes of your own.
- A missing required argument ends with [exit code](#-exit-codes) `64`.
- Named and positional arguments can be used together. Hooks do not get arguments.

## 🪜 Steps

Run several commands one after another with `$steps`. A step is a command or a [reference](#-references). rps stops at the first step that fails and exits with its exit code.

```yaml
scripts:
  analyze: dart analyze --fatal-infos
  check:
    $steps:
      - dart format --set-exit-if-changed .
      - rps analyze
      - dart test
```

Unlike `&&`, this works the same in every shell, including PowerShell on Windows.

- Use `$steps` instead of `$script`, not together with it.
- Positional and named arguments are filled in every step. Other arguments are rejected, because there is no single command to add them to.
- A step can be platform specific, like `$script`: `- { $default: rm -rf build, $windows: rd /s /q build }`.
- Write steps that contain `${...}` as a list with dashes. Inside `[...]` YAML needs them in quotes.

## 🧵 Parallel scripts

Run commands at the same time with `$parallel`. Every line of the output starts with the name of the command it comes from.

```yaml
scripts:
  analyze: dart analyze
  test: dart test
  verify:
    $parallel:
      - rps analyze
      - rps test
      - dart format --set-exit-if-changed .
```

```
$ rps verify
> verify (3 in parallel)

[analyze] No issues found!
[3      ] Formatted 42 files (0 changed) in 0.31 seconds.
[test   ] 00:04 +128: All tests passed!
```

- A reference is labeled with its script, a plain command with its number.
- When one command fails, the others are stopped and rps exits with the exit code of the failed one.
- The commands have no terminal: they cannot ask for input, and most programs turn their colors off.
- `$parallel` can be a step of `$steps`, and the other way round, through references.

## 🌱 Environment variables

Set environment variables with `$env`, for one script or for a whole group. A script inherits the variables of its groups, the closest one wins.

```yaml
scripts:
  $env:
    APP_ENV: dev
  build:
    $env:
      APP_ENV: prod
    $script: flutter build apk
  run: flutter run
```

Variables can also come from a file. `$envFile` takes a path or a list of paths, relative to the project:

```yaml
scripts:
  $envFile: .env
  deploy:
    $envFile: [.env, .env.deploy]
    $script: dart run tool/deploy.dart
```

- A variable that is already set in your shell or in CI is **not** replaced by an env file, but it is replaced by `$env`.
- With several files, a later file wins.
- An env file has `NAME=value` lines. Empty lines and lines starting with `#` are skipped, a leading `export` is allowed, and values can be quoted.
- An env file is read only when you ask for it. A missing file is an error.
- Values are never printed by `rps ls` or `--dry-run`.

## 📂 Working directory

`$cwd` runs a script, or all scripts of a group, in another directory. The path is relative to the project.

```yaml
scripts:
  app:
    $cwd: packages/app
    build: flutter build apk
    test: flutter test
```

A directory that does not exist is an error.

## ✋ Confirmation

Add `$confirm` to a script that should not run by accident. rps asks before it runs anything, also when the script is a step of another script.

```yaml
scripts:
  db:
    reset:
      $confirm: Drop the local database?
      $script: dart run tool/reset_db.dart
```

```
$ rps db reset
Drop the local database? (y/N)
```

- `$confirm: true` asks a default question.
- `rps --yes db reset` (or `-y`) answers yes. So does the `RPS_YES=1` environment variable.
- Without a terminal, for example in CI, rps does not run the script unless `--yes` is given, and exits with code `64`.
- `--dry-run` shows the question and does not ask.

## 📝 External scripts file

If you prefer to keep your scripts separate from your `pubspec.yaml`, you can define them in an external **`rps.yaml`** file. When an `rps.yaml` file is present in your project's root directory, rps will use it as the scripts source **instead of the scripts in `pubspec.yaml`**.

To use an external scripts file:
1. Create an `rps.yaml` file in the root of your project.
2. Define your scripts under the `scripts` key, just like you would in `pubspec.yaml`.
    ```yaml
    scripts:
      clean:
        $script:
          $default: rm -rf ./build
          $windows: rd /s /q build
      build:
        release: flutter build apk --release
        debug: flutter build apk --debug
    ```
3. Run your scripts using rps as usual:
    ```bash
    rps clean
    rps build release
    ```
Using `rps.yaml` allows you to keep your `pubspec.yaml` file focused on dependencies and package configuration, while managing your scripts in a dedicated file.

### Picking an interpreter

The same `rps.yaml` lets you choose the shell that runs your scripts on Linux and macOS. On Windows scripts always run in PowerShell.

```yaml
linux:
  interpreter: zsh        # bash (default) | sh | zsh
macos:
  interpreter: zsh        # bash (default) | sh | zsh
```

## 🛠 CLI options

| Option            | Description                                                                |
| ----------------- | -------------------------------------------------------------------------- |
| `-h`, `--help`    | Print help.                                                                |
| `--version`       | Print rps version.                                                         |
| `-u`, `--upgrade` | Upgrade rps to the latest version (runs `dart pub global activate rps`).   |
| `-n`, `--dry-run` | Print the commands of a script, with hooks, without running them.          |
| `-y`, `--yes`     | Confirm scripts that ask for [confirmation](#-confirmation).               |
| `--no-color`      | Disable colored output.                                                    |

`--dry-run`, `--yes` and `--no-color` go before the script name, for example `rps --dry-run build apk` or `rps run --dry-run build apk`. Everything after the script name is passed to the script.

```
$ rps --dry-run build android apk
> build before
$ flutter pub get

> build android apk before
$ echo "Building android apk..."

> build android apk
$ flutter build --release apk --flavor production

> build after
$ echo "Build done!"
```

Colors are also disabled when the output is not a terminal, when the `NO_COLOR` environment variable is set, or when `TERM` is `dumb`. The output of your scripts is never changed.

rps checks for a new version once a day and shows a notice when one is available. The check runs only when the output is a terminal and not in CI. Set `RPS_NO_UPDATE_CHECK=1` to turn it off.

## 🚦 Exit codes

| Code  | Meaning                                                                                                                                        |
| ----- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `0`   | Success.                                                                                                                                       |
| `64`  | The script does not exist, the path is incomplete, an argument is missing or not accepted, an option is unknown, or a script needs `--yes`.     |
| `78`  | Configuration problem: `pubspec.yaml` or `rps.yaml` is missing or invalid, there is no `scripts` key, or a script is defined incorrectly.       |
| `1`   | Any other rps error, or a [confirmation](#-confirmation) that was declined.                                                                    |
| other | The exit code of the failed script or hook, passed through unchanged.                                                                          |

rps stops at the first command that fails. A script can itself exit with `1`, `64` or `78`; the error message on stderr tells the two cases apart.

## 🤖 Using rps with AI agents

rps works without a terminal, so coding agents and other tools can use it the same way as CI does.

- **Find the scripts** with `rps ls --json`. Each entry has the path to run, the command, a description, the positional arguments and any errors. Add a `$description` to your scripts, the agent reads it to pick the right one.
- **Check before running** with `rps --dry-run <script>`. It prints every command that would run, hooks included, and runs nothing.
- **Confirm on purpose.** A script with a `confirm` question in `rps ls --json` does not run without a terminal. Pass `rps --yes <script>` only when running it is really intended.
- **Run** with `rps <script> [arguments]`. Without a terminal there is no menu, no update notice and no colors.
- **Read the result** from the [exit code](#-exit-codes). Errors of rps go to stderr, the output of the script is passed through as it is.

If the agent runs in a terminal emulator, set `CI=1` to turn off the menu and the update notice, and `NO_COLOR=1` to turn off colors.

A short note for your `AGENTS.md` or `CLAUDE.md`:

```markdown
Project scripts are run with rps. List them with `rps ls --json`,
preview one with `rps --dry-run <script>` and run it with `rps <script>`.
Exit code 64 means the script does not exist, 78 means a configuration error.
```

## 🔎 Overview example

```yaml
name: my_great_app
version: 1.0.0

scripts:
  # run is a default script. To use it, simply type
  # in the command line: "rps" - that's all!
  run: "flutter run -t lib/main_development.dart --flavor development"
  # you can define more commands like this: "rps gen"
  gen: "flutter pub run build_runner watch --delete-conflicting-outputs"
  # and even nest them!
  build:
    # You can use hooks to! (and even nest them!)
    $before: flutter pub get
    $after: echo "Build done!"
    android:
      # rps build android apk
      apk: 
        $before: echo "Building android apk..."
        $script: "flutter build --release apk --flavor production"
      # rps build android appbundle
      appbundle: "flutter build --release appbundle --flavor production"
      # and so on...
  # too long command? no problem! define alias using reference syntax!
  bab: rps build android appbundle
  # as simple as typing "rps baa"
  baa: rps build android apk
  # some commands may vary from platform to platform
  # but that's not a problem
  clear:
    # use the $script key to define platform specific scripts
    $script:
      # define the default script
      $default: rm -rf ./app/cache
      # And different script for the windows platform.
      $windows: rd /s /q app\cache
      # now "rps clear" will work on any platform!
  # want to run multi line script, here is an example
  reset: |
    flutter clean 
    flutter pub get

  # the rest of your pubspec file...
dependencies:
  path: ^1.7.0
```

___

## Supported platforms

rps is written in pure Dart and runs on every desktop platform the Dart SDK supports: Linux, macOS and Windows.


---

## 📈 Motivation

I got bored of typing the same long commands over and over again... I even got bored of pressing that boring (and even small on a MacBook) up arrow key to find my previous command in history. So, as befits a programmer, to save time, I spent more time writing this library than searching/writing commands for the last year...

![stonks](./stonks.jpg)

---

Hey you! This package is still in development (errors and API changes can still occur 🐛😏).
