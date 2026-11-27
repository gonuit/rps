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

    if (!value.containsKey(ScriptsParser.scriptKey)) {
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

    final command = _command(value[ScriptsParser.scriptKey], path, errors);
    return Script(
      command: command,
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
