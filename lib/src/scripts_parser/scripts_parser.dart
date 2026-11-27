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

  /// Key for the entry with commands run one after another.
  static const stepsKey = r'$steps';

  /// Key for the entry with commands run at the same time.
  static const parallelKey = r'$parallel';

  /// Key for the named arguments entry.
  static const argsKey = r'$args';

  /// Key for the confirmation entry.
  static const confirmKey = r'$confirm';

  /// Key for the working directory entry.
  static const cwdKey = r'$cwd';

  /// Key for the environment variables entry.
  static const envKey = r'$env';

  /// Key for the env files entry.
  static const envFileKey = r'$envFile';

  /// Returns `true` if [key] is a reserved special key.
  static bool isSpecialKey(String key) => switch (key) {
        scriptKey ||
        beforeKey ||
        afterKey ||
        descriptionKey ||
        defaultScriptKey ||
        stepsKey ||
        parallelKey ||
        argsKey ||
        confirmKey ||
        cwdKey ||
        envKey ||
        envFileKey =>
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
  final Map<String, String> env;
  final List<String> envFiles;

  const _Scope({this.cwd, this.env = const {}, this.envFiles = const []});

  _Scope enter(ScriptNode? node) {
    if (node == null) return this;
    return _Scope(
      cwd: node.cwd ?? cwd,
      env: {...env, ...node.env},
      envFiles: [...envFiles, ...node.envFiles],
    );
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
          declaredArguments: node.args,
          confirmation: _confirmation(node, context),
          workingDirectory: scope.cwd,
          environment: scope.env,
          envFiles: scope.envFiles,
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
    if (node is Script && node.confirm) {
      yield ConfirmationRequired(
        context: context,
        message: _confirmation(node, context)!,
      );
    }

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
        final entered = _enter(stack, context.basePath.join(' '));
        final (named, positional) = _named(node, context, arguments);
        final steps = node.steps;
        final parallel = node.parallel;
        if (parallel != null) {
          _checkArguments(node, context, positional);
          yield ParallelExecuted(
            context: context,
            branches: [
              for (final (index, command) in parallel.indexed)
                ParallelBranch(
                  label: command.startsWith('rps ')
                      ? command.substring(4).trim()
                      : '${index + 1}',
                  events: _command(
                    root,
                    context: context,
                    command: command,
                    arguments: positional,
                    named: named,
                    stack: entered,
                    scope: scope,
                    step: (index + 1, parallel.length),
                  ).toList(),
                ),
            ],
          );
        } else if (steps == null) {
          yield* _command(
            root,
            context: context,
            command: node.command,
            arguments: positional,
            named: named,
            stack: entered,
            scope: scope,
          );
        } else {
          _checkArguments(node, context, positional);
          for (final (index, step) in steps.indexed) {
            yield* _command(
              root,
              context: context,
              command: step,
              arguments: positional,
              named: named,
              stack: entered,
              scope: scope,
              step: (index + 1, steps.length),
            );
          }
        }
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

  String? _confirmation(Script script, Context context) {
    if (!script.confirm) return null;
    return script.confirmMessage ??
        'Run the script "${context.basePath.join(' ')}"?';
  }

  void _checkArguments(Script script, Context context, List<String> arguments) {
    final expected = CommandExecuted.getScriptArguments(script.command).length;
    if (arguments.length <= expected) return;
    throw RpsUsageException(
      'The script "${context.basePath.join(' ')}" runs several commands, '
      'so it does not accept additional arguments: '
      '${arguments.skip(expected).join(' ')}',
    );
  }

  (Map<String, String>, List<String>) _named(
    Script script,
    Context context,
    List<String> arguments,
  ) {
    if (script.args.isEmpty) return (const {}, arguments);

    final path = context.basePath.join(' ');
    final values = {
      for (final argument in script.args)
        if (argument.defaultValue != null)
          argument.name: argument.defaultValue!,
    };
    final names = script.args.map((argument) => argument.name).toSet();
    final rest = <String>[];
    for (var i = 0; i < arguments.length; i++) {
      final argument = arguments[i];
      if (argument == '--') {
        rest.addAll(arguments.skip(i + 1));
        break;
      }
      final separator = argument.indexOf('=');
      final name = !argument.startsWith('--')
          ? null
          : argument.substring(2, separator < 0 ? null : separator);
      if (!names.contains(name)) {
        rest.add(argument);
      } else if (separator >= 0) {
        values[name!] = argument.substring(separator + 1);
      } else if (i + 1 < arguments.length) {
        values[name!] = arguments[++i];
      } else {
        throw RpsUsageException(
          'The argument "--$name" of the script "$path" needs a value.',
        );
      }
    }

    final missing = names.where((name) => !values.containsKey(name));
    if (missing.isNotEmpty) {
      throw RpsUsageException(
        'The script "$path" requires the argument(s): '
        '${missing.map((name) => '--$name').join(', ')}.',
      );
    }
    return (values, rest);
  }

  static final _placeholder =
      RegExp(r'\$\{\s*([0-9]+|[A-Za-z_][A-Za-z0-9_-]*)\s*\}');

  String _fill(
    String word,
    Context context,
    List<String> arguments,
    Map<String, String> named, {
    required bool positional,
  }) {
    return word.replaceAllMapped(_placeholder, (match) {
      final index = int.tryParse(match[1]!);
      if (index == null) return named[match[1]!] ?? match[0]!;
      if (!positional) return match[0]!;
      if (index >= arguments.length) {
        throw RpsUsageException(
          'The script "${context.basePath.join(' ')}" defines a positional '
          'argument ${match[0]}, but ${arguments.length} positional '
          'argument(s) are given.',
        );
      }
      return arguments[index];
    });
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
    Map<String, String> named = const {},
    bool isHook = false,
    (int, int)? step,
  }) sync* {
    if (!command.startsWith(r'rps ')) {
      yield CommandExecuted(
        command: command,
        context: context,
        arguments: arguments,
        named: named,
        isHook: isHook,
        step: step,
        workingDirectory: scope.cwd,
        environment: scope.env,
        envFiles: scope.envFiles,
      );
      return;
    }

    final words = [
      for (final word in command.substring(4).trim().split(RegExp(r'\s+')))
        _fill(
          word,
          context,
          arguments ?? const [],
          named,
          positional: step != null,
        ),
    ];
    yield CommandReferenced(
      command: words.join(' '),
      context: context,
      label: context.key!,
      isHook: isHook,
      step: step,
    );

    // Ref should start from root.
    yield* _resolve(
      root,
      root,
      Context(key: null, parent: context, isBase: true, current: root),
      step == null ? [...words, ...?arguments] : words,
      stack,
      const _Scope(),
    );
  }
}
