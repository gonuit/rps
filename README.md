# Run Pubspec Script (RPS)

Define and use scripts from your _pubspec.yaml_ file.

## Getting started

1. Install this package.

   ```bash
   dart pub global activate rps
   ```

2. Define script inside the pubspec.yaml

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
         apk: "flutter build --release apk --flavor production"
         # rps build android appbundle
         appbundle: "flutter build --release appbundle --flavor production"
         # and so on...
     # too long command? no problem! define alias using reference syntax!
     bab: $build android appbundle
     # as simple as typing "rps baa"
     baa: $build android apk 
     # some commands may vary from platform to platform
     # but that's not a problem
     clear:
       # use the $script key to define platform specific scripts
       $script:
         # define the default script
         $default: rm -rf ./cache
         # And different script for the windows platform.
         $windows: rd /s /q ./cache
         # now "rps clear" will work on any platform!


   # the rest of your pubspec file...
   dependencies:
     path: ^1.7.0
   ```

3. Use your custom command.

   Like this `gen` command that we defined in the previous step:

   ```bash
   rps gen
   ```

   instead of

   ```bash
    flutter pub run build_runner watch --delete-conflicting-outputs
   ```

4. Safe a time and become a power user! 😈

   Less time typing long commands more time watching funny cats. 🐈

## Nesting

Nest your commands to group them contextually and make them easier to understand 🧪

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

## References

Sometimes you may want to create a command alias (e.g. a shorter version of it) or simply pass the execution of a hook to another command. This is where references come to the rescue! ⛑

References are defined as a scripts that must begin with `$` sign.

```yaml
scripts:
  generator:
    build: flutter pub run build_runner build --delete-conflicting-outputs
    watch: flutter pub run build_runner watch --delete-conflicting-outputs
  # short aliases:
  gb: $generator build # same as "rps run generator build"
  gw: $generator watch # same as "rps run generator watch"
```

References can also be used with `$before` and `$after` hooks.

## Hooks

To enable hooks define the `$before` and/or `$after` keys for your script command.

```yaml
scripts:
  hooks:
    $before: echo "hello before" # executed before the $script
    $script: echo "hello script"
    $after: echo "hello after" # executed after $script
```

Execute as always.

```
user@MacBook-Pro Desktop % rps hooks
> hooks $before
$ echo "hello before"

hello before

> hooks
$ echo "hello script"

hello script

> hooks $after
$ echo "hello after"

hello after
```

You can also combine multiple scripts using references!

```yaml
scripts:
  get: flutter pub get
  test:
    # equivalent of "rps run get"
    $before: $get
    $script: flutter test
  build:
    # equivalent of "rps run test"
    $before: $test
    $script: flutter build apk
```

But wait a minute! The hooks can also be nested!

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

## Platform specific scripts

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

---

## Motivation

I got bored of typing the same long commands over and over again... I even got bored of pressing that boring (and even small on a MacBook) up arrow key to find my previous command in history. So, as befits a programmer, to save time, I spent more time writing this library than searching/writing commands for the last year...

![stonks](./stonks.jpg)

## Soon

- Further hooks improvements.

---

Hey you! This package is still in development (bugs may occur 🐛😏).
