import 'package:collection/collection.dart';
import 'package:rps/rps.dart';
import 'package:rps/src/utils/platform.dart' show Platform;

/// Parses and resolves scripts from a [ScriptsSource].
abstract class ScriptsParser {
  /// Key for the before-hook entry.
  static const beforeKey = r'$before';

  /// Key for the after-hook entry.
  static const afterKey = r'$after';

  /// Key for the script value entry.
  static const scriptKey = r'$script';

  /// Key for the description entry.
  static const descriptionKey = r'$description';

  /// Key for the default platform script entry.
  static const defaultScriptKey = r'$default';

  /// Returns `true` if [key] is a reserved special key.
  static bool isSpecialKey(String key) => switch (key) {
        scriptKey ||
        beforeKey ||
        afterKey ||
        descriptionKey ||
        defaultScriptKey =>
          true,
        _ => false,
      };

  /// Lists all available commands from the scripts source.
  List<CommandExecuted> listCommands();

  /// Resolves [arguments] into an ordered list of execution events.
  List<ExecutionEvent> getCommandsToExecute(List<String> arguments);

  /// Creates a [ScriptsParser] for the given [source].
  factory ScriptsParser({
    required ScriptsSource source,
    required Platform platform,
  }) = _ScriptParser;
}

class _ScriptParser implements ScriptsParser {
  final ScriptsSource _source;
  final ScriptsAnalyzer _analyzer;

  _ScriptParser({
    required ScriptsSource source,
    required Platform platform,
  })  : _source = source,
        _analyzer = ScriptsAnalyzer(platform: platform);

  ScriptNode _analyze() => _analyzer.analyze(_source.getScripts());

  Context _child(Context context, String key, ScriptNode? node) {
    return Context(key: key, parent: context, current: node, isBase: false);
  }

  @override
  List<CommandExecuted> listCommands() {
    final root = _analyze();
    return _listCommands(root, Context.root(root)).toList();
  }

  Iterable<CommandExecuted> _listCommands(
    ScriptNode node,
    Context context,
  ) sync* {
    switch (node) {
      case Script():
        yield CommandExecuted(
          command: node.command,
          context: context,
          description: node.description,
          errors: [if (node.error != null) node.error!],
        );
      case ScriptGroup():
        for (final MapEntry(:key, :value) in node.children.entries) {
          yield* _listCommands(value, _child(context, key, value));
        }
    }
  }

  @override
  List<ExecutionEvent> getCommandsToExecute(List<String> arguments) {
    final root = _analyze();
    var context = Context.root(root);
    ScriptNode? node = root;
    // If command is not specified, fallback to run
    if (arguments.isEmpty) {
      node = root is ScriptGroup ? root.children['run'] : null;
      context = _child(context, 'run', node);
    }

    final events = <ExecutionEvent>{};
    for (final event in _resolve(root, node, context, arguments)) {
      final added = events.add(event);
      if (!added) {
        throw RpsConfigException(
          'Script cycle detected: ${[
            ...events.map((e) => e.path),
            event.path
          ].join(' → ')}',
        );
      }
    }

    return events.toList();
  }

  Iterable<ExecutionEvent> _resolve(
    ScriptNode root,
    ScriptNode? node,
    Context context,
    List<String> arguments,
  ) sync* {
    if (node == null) {
      throw RpsUsageException(
        'Missing script. Command: "${context.basePath.join(' ')}" not found.',
      );
    }

    yield* _hook(root, context, node.before, ScriptsParser.beforeKey, 'before');

    switch (node) {
      case Script():
        final error = node.error;
        if (error != null) throw RpsConfigException(error);
        yield* _command(
          root,
          context: context,
          command: node.command,
          arguments: arguments,
        );
      case ScriptGroup():
        final nextKey = arguments.firstOrNull;
        if (nextKey == null) {
          throw RpsUsageException(
            'Missing script. Command: "${context.path}" '
            'is not a full path.',
          );
        }
        final child = node.children[nextKey];
        yield* _resolve(
          root,
          child,
          _child(context, nextKey, child),
          arguments.skip(1).toList(),
        );
    }

    yield* _hook(root, context, node.after, ScriptsParser.afterKey, 'after');
  }

  Iterable<ExecutionEvent> _hook(
    ScriptNode root,
    Context context,
    String? command,
    String key,
    String name,
  ) sync* {
    if (command == null) return;
    final hookContext = _child(context, key, null);
    yield HookExecuted(command: command, context: hookContext, name: name);
    // arguments are not passed to the hooks
    yield* _command(
      root,
      context: hookContext,
      command: command,
      isHook: true,
    );
  }

  Iterable<ExecutionEvent> _command(
    ScriptNode root, {
    required Context context,
    required String command,
    List<String>? arguments,
    bool isHook = false,
  }) sync* {
    if (!command.startsWith(r'rps ')) {
      yield CommandExecuted(
        command: command,
        context: context,
        arguments: arguments,
        isHook: isHook,
      );
      return;
    }

    final referencedCommand = command.substring(4).trim();
    yield CommandReferenced(
      command: referencedCommand,
      context: context,
      label: context.key!,
      isHook: isHook,
    );

    // Ref should start from root.
    yield* _resolve(
      root,
      root,
      Context(key: null, parent: context, isBase: true, current: root),
      [
        ...referencedCommand.split(RegExp(r'\s+')),
        ...?arguments,
      ],
    );
  }
}
