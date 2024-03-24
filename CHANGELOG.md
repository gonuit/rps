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
