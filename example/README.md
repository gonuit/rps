# RPS Example

Define scripts in your `pubspec.yaml`:

```yaml
scripts:
  gen: flutter pub run build_runner build --delete-conflicting-outputs
  build:
    web:
      $script: flutter build web --flavor production -t lib/main.dart
      $description: Builds a web application
    android:
      $script: flutter build apk --flavor production -t lib/main.dart
      $description: Builds an Android app
```

Then run them with:

```bash
rps gen
rps build web
rps ls
```

See the [README](https://github.com/gonuit/rps) for full documentation.
