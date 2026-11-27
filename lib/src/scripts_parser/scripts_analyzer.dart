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

    final before = _string(value[ScriptsParser.beforeKey]);
    final after = _string(value[ScriptsParser.afterKey]);
    final unknownKeys = value.keys
        .map((key) => '$key')
        .where((key) => key.startsWith(r'$'))
        .where((key) => !ScriptsParser.isSpecialKey(key));
    final unknownKeysError = unknownKeys.isEmpty
        ? null
        : 'Unknown key: ${unknownKeys.map((key) => '"$key"').join(', ')}.';

    if (!value.containsKey(ScriptsParser.scriptKey)) {
      return ScriptGroup(
        before: before,
        after: after,
        error: unknownKeysError,
        children: {
          for (final key in value.keys)
            if (!'$key'.startsWith(r'$'))
              '$key': _node(value[key], [...path, '$key']),
        },
      );
    }

    final description = _string(value[ScriptsParser.descriptionKey]);
    final script = value[ScriptsParser.scriptKey];
    if (script is String) {
      return Script(
        command: script,
        description: description,
        error: unknownKeysError,
        before: before,
        after: after,
      );
    }
    if (script is! Map) {
      return Script(
        command: script.toString(),
        description: description,
        error: _invalidType(script),
        before: before,
        after: after,
      );
    }

    final platformKey = '\$${_platform.operatingSystem}';
    final command =
        script[platformKey] ?? script[ScriptsParser.defaultScriptKey];
    if (command is String) {
      return Script(
        command: command,
        description: description,
        error: unknownKeysError,
        before: before,
        after: after,
      );
    }
    return Script(
      command: '-',
      description: description,
      before: before,
      after: after,
      error: 'No platform script key for the command: "${path.join(' ')}". '
          'Consider adding the key for the current '
          'platform: "$platformKey" or the default script '
          'key: "${ScriptsParser.defaultScriptKey}".',
    );
  }

  String? _string(dynamic value) => value is String ? value : null;

  String _invalidType(dynamic value) => 'Invalid command. Cannot use type '
      '${value.runtimeType} ($value) as a command.';
}
