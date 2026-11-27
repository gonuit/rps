import 'package:rps/rps.dart';
import 'package:rps/src/utils/platform.dart' show Platform;

/// Turns the raw `scripts` value into a tree of [ScriptNode]s.
class ScriptsAnalyzer {
  final Platform _platform;

  /// Creates a [ScriptsAnalyzer].
  const ScriptsAnalyzer({required Platform platform}) : _platform = platform;

  /// Analyzes the raw [scripts] value.
  ScriptNode analyze(dynamic scripts) {
    if (scripts is String) {
      return Script(
        command: scripts,
        error: 'The root key "scripts" cannot contain commands.',
      );
    }
    return _node(scripts, const []);
  }

  ScriptNode _node(dynamic value, List<String> path) {
    if (value is String) {
      return Script(command: value);
    }
    if (value is! Map) {
      return Script(command: value.toString(), error: _invalidType(value));
    }

    final errors = <String>[];
    final unknownKeys = value.keys
        .map((key) => '$key')
        .where((key) => key.startsWith(r'$'))
        .where((key) => !ScriptsParser.isSpecialKey(key));
    if (unknownKeys.isNotEmpty) {
      errors.add(
        'Unknown key: ${unknownKeys.map((key) => '"$key"').join(', ')}.',
      );
    }

    final before = _string(value[ScriptsParser.beforeKey]);
    final after = _string(value[ScriptsParser.afterKey]);
    final cwd = _cwd(value, errors);
    final env = _env(value[ScriptsParser.envKey], errors);
    final envFiles = _envFiles(value[ScriptsParser.envFileKey], errors);

    final hasScript = value.containsKey(ScriptsParser.scriptKey);
    final hasSteps = value.containsKey(ScriptsParser.stepsKey);
    final hasParallel = value.containsKey(ScriptsParser.parallelKey);
    final kinds = [hasScript, hasSteps, hasParallel].where((has) => has);
    if (kinds.isEmpty) {
      for (final key in [ScriptsParser.argsKey, ScriptsParser.confirmKey]) {
        if (value.containsKey(key)) {
          errors.add('The "$key" key can be used only in a script.');
        }
      }
      return ScriptGroup(
        before: before,
        after: after,
        cwd: cwd,
        env: env,
        envFiles: envFiles,
        error: _join(errors),
        children: {
          for (final key in value.keys)
            if (!'$key'.startsWith(r'$'))
              '$key': _node(value[key], [...path, '$key']),
        },
      );
    }

    if (kinds.length > 1) {
      errors.add(
        'Use only one of "${ScriptsParser.scriptKey}", '
        '"${ScriptsParser.stepsKey}" and "${ScriptsParser.parallelKey}".',
      );
    }
    final parallel = hasParallel
        ? _commands(
            value[ScriptsParser.parallelKey],
            ScriptsParser.parallelKey,
            path,
            errors,
          )
        : null;
    final steps = hasSteps
        ? _commands(
            value[ScriptsParser.stepsKey],
            ScriptsParser.stepsKey,
            path,
            errors,
          )
        : null;
    final confirm = value[ScriptsParser.confirmKey];
    final command = steps?.join('\n') ??
        parallel?.join('\n') ??
        _command(value[ScriptsParser.scriptKey], path, errors);
    return Script(
      command: command,
      steps: steps,
      parallel: parallel,
      args: _args(value[ScriptsParser.argsKey], errors),
      confirm: _confirm(confirm, errors),
      confirmMessage: confirm is String ? confirm : null,
      description: _string(value[ScriptsParser.descriptionKey]),
      before: before,
      after: after,
      cwd: cwd,
      env: env,
      envFiles: envFiles,
      error: _join(errors),
    );
  }

  String _command(dynamic script, List<String> path, List<String> errors) {
    if (script is String) return script;
    if (script is! Map) {
      errors.add(_invalidType(script));
      return script.toString();
    }

    final platformKey = '\$${_platform.operatingSystem}';
    final command =
        script[platformKey] ?? script[ScriptsParser.defaultScriptKey];
    if (command is String) return command;
    errors.add(
      'No platform script key for the command: "${path.join(' ')}". '
      'Consider adding the key for the current '
      'platform: "$platformKey" or the default script '
      'key: "${ScriptsParser.defaultScriptKey}".',
    );
    return '-';
  }

  List<String> _commands(
    dynamic commands,
    String key,
    List<String> path,
    List<String> errors,
  ) {
    if (commands is! List || commands.isEmpty) {
      errors.add('The "$key" key must be a list of commands.');
      return const [];
    }
    return [for (final command in commands) _command(command, path, errors)];
  }

  static final _argumentName = RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*$');

  List<ScriptArgument> _args(dynamic args, List<String> errors) {
    if (args == null) return const [];
    if (args is! Map) {
      errors.add('The "${ScriptsParser.argsKey}" key must be a map.');
      return const [];
    }
    final arguments = <ScriptArgument>[];
    for (final MapEntry(key: name, :value) in args.entries) {
      if (name is! String || !_argumentName.hasMatch(name)) {
        errors.add('Invalid argument name: "$name".');
      } else if (value == null) {
        arguments.add(ScriptArgument(name));
      } else if (value is String || value is num || value is bool) {
        arguments.add(ScriptArgument(name, defaultValue: '$value'));
      } else {
        errors.add(
          'The default value of the argument "$name" must be '
          'a string, a number or a boolean.',
        );
      }
    }
    return arguments;
  }

  bool _confirm(dynamic confirm, List<String> errors) {
    if (confirm == null || confirm is bool) return confirm == true;
    if (confirm is String && confirm.trim().isNotEmpty) return true;
    errors.add(
      'The "${ScriptsParser.confirmKey}" key must be "true" or a question.',
    );
    return false;
  }

  String? _cwd(Map<dynamic, dynamic> value, List<String> errors) {
    final cwd = value[ScriptsParser.cwdKey];
    if (cwd == null || cwd is String) return cwd as String?;
    errors.add('The "${ScriptsParser.cwdKey}" key must be a path.');
    return null;
  }

  Map<String, String> _env(dynamic env, List<String> errors) {
    if (env == null) return const {};
    if (env is! Map) {
      errors.add('The "${ScriptsParser.envKey}" key must be a map.');
      return const {};
    }
    final variables = <String, String>{};
    for (final MapEntry(key: name, :value) in env.entries) {
      if (name is! String || name.isEmpty || name.contains('=')) {
        errors.add('Invalid environment variable name: "$name".');
      } else if (value is String || value is num || value is bool) {
        variables[name] = '$value';
      } else {
        errors.add(
          'The environment variable "$name" must be '
          'a string, a number or a boolean.',
        );
      }
    }
    return variables;
  }

  List<String> _envFiles(dynamic files, List<String> errors) {
    if (files == null) return const [];
    if (files is String) return [files];
    if (files is List && files.every((file) => file is String)) {
      return files.cast<String>().toList();
    }
    errors.add(
      'The "${ScriptsParser.envFileKey}" key must be a path '
      'or a list of paths.',
    );
    return const [];
  }

  String? _join(List<String> errors) =>
      errors.isEmpty ? null : errors.join('\n');

  String? _string(dynamic value) => value is String ? value : null;

  String _invalidType(dynamic value) => 'Invalid command. Cannot use type '
      '${value.runtimeType} ($value) as a command.';
}
