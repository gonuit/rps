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
         android:
         # rps build android apk
         apk: "flutter build --release apk --flavor production"
         # rps build android appbundle
         appbundle: "flutter build --release appbundle --flavor production"
         # and so on...

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

## Hooks
You can use commands that will be executed **before** or **after** some command. Have a look at these scripts in the `pubspec.yaml` file.
```yaml
scripts:
  test:
    before-echo: echo "before-test"
    echo: echo "test" 
    after-echo: echo "after-test"
```
Running `rps test echo` command produces following output:
```
> test before-echo
$ echo "before-test"

before-test

> test echo
$ echo "test"

test

> test after-echo
$ echo "after-test"
```

---

## Motivation

I got bored of typing the same long commands over and over again... I even got bored of pressing that boring (and even small on a MacBook) up arrow key to find my previous command in history. So, as befits a programmer, to save time, I spent more time writing this library than searching/writing commands for the last year...

![stonks](./stonks.jpg)

## Soon

- Further hooks improvements.

___

Hey you! This package is still in development (bugs may occur 🐛😏).
