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

  /// Key for the working directory entry.
  static const cwdKey = r'$cwd';

  /// Returns `true` if [key] is a reserved special key.
  static bool isSpecialKey(String key) => switch (key) {
        scriptKey ||
        beforeKey ||
        afterKey ||
        descriptionKey ||
        defaultScriptKey ||
        cwdKey =>
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

class _Scope {
  final String? cwd;

  const _Scope({this.cwd});

  _Scope enter(ScriptNode? node) {
    if (node == null) return this;
    return _Scope(cwd: node.cwd ?? cwd);
  }
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
    return _listCommands(root, Context.root(root), const [], const _Scope())
        .toList();
  }

  Iterable<CommandExecuted> _listCommands(
    ScriptNode node,
    Context context,
    List<String> inheritedErrors,
    _Scope parentScope,
  ) sync* {
    final errors = [...inheritedErrors, if (node.error != null) node.error!];
    final scope = parentScope.enter(node);
    switch (node) {
      case Script():
        yield CommandExecuted(
          command: node.command,
          context: context,
          description: node.description,
          errors: errors,
          workingDirectory: scope.cwd,
        );
      case ScriptGroup():
        for (final MapEntry(:key, :value) in node.children.entries) {
          yield* _listCommands(
            value,
            _child(context, key, value),
            errors,
            scope,
          );
        }
    }
  }

  @override
  List<ExecutionEvent> getCommandsToExecute(List<String> arguments) {
    final root = _analyze();
    var context = Context.root(root);
    ScriptNode? node = root;
    var scope = const _Scope();
    // If command is not specified, fallback to run
    if (arguments.isEmpty) {
      node = root is ScriptGroup ? root.children['run'] : null;
      context = _child(context, 'run', node);
      scope = scope.enter(root);
    }

    return _resolve(root, node, context, arguments, const [], scope).toList();
  }

  Iterable<ExecutionEvent> _resolve(
    ScriptNode root,
    ScriptNode? node,
    Context context,
    List<String> arguments,
    List<String> stack,
    _Scope parentScope,
  ) sync* {
    if (node == null) {
      throw RpsUsageException(
        'Missing script. Command: "${context.basePath.join(' ')}" not found.',
      );
    }
    final error = node.error;
    if (error != null) throw RpsConfigException(error);
    final scope = parentScope.enter(node);

    yield* _hook(
      root,
      context,
      node.before,
      ScriptsParser.beforeKey,
      'before',
      stack,
      scope,
    );

    switch (node) {
      case Script():
        yield* _command(
          root,
          context: context,
          command: node.command,
          arguments: arguments,
          stack: _enter(stack, context.basePath.join(' ')),
          scope: scope,
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
          stack,
          scope,
        );
    }

    yield* _hook(
      root,
      context,
      node.after,
      ScriptsParser.afterKey,
      'after',
      stack,
      scope,
    );
  }

  Iterable<ExecutionEvent> _hook(
    ScriptNode root,
    Context context,
    String? command,
    String key,
    String name,
    List<String> stack,
    _Scope scope,
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
      stack: _enter(stack, hookContext.basePath.join(' ')),
      scope: scope,
    );
  }

  List<String> _enter(List<String> stack, String path) {
    if (stack.contains(path)) {
      throw RpsConfigException(
        'Script cycle detected: ${[...stack, path].join(' → ')}',
      );
    }
    return [...stack, path];
  }

  Iterable<ExecutionEvent> _command(
    ScriptNode root, {
    required Context context,
    required String command,
    required List<String> stack,
    required _Scope scope,
    List<String>? arguments,
    bool isHook = false,
  }) sync* {
    if (!command.startsWith(r'rps ')) {
      yield CommandExecuted(
        command: command,
        context: context,
        arguments: arguments,
        isHook: isHook,
        workingDirectory: scope.cwd,
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
      stack,
      const _Scope(),
    );
  }
}
