import 'dart:io';
import 'package:collection/collection.dart';
import 'package:rps/rps.dart';

abstract class ScriptsParser {
  static const beforeKey = r'$before';
  static const afterKey = r'$after';
  static const scriptKey = r'$script';
  static const descriptionKey = r'$description';
  static const defaultScriptKey = r'$default';

  static isSpecialKey(String key) => switch (key) {
        scriptKey ||
        beforeKey ||
        afterKey ||
        descriptionKey ||
        defaultScriptKey =>
          true,
        _ => false,
      };

  List<CommandExecuted> listCommands();
  List<ExecutionEvent> getCommandsToExecute(List<String> arguments);

  factory ScriptsParser({required ScriptsSource source}) = _ScriptParser;
}

class _ScriptParser implements ScriptsParser {
  final ScriptsSource _source;

  _ScriptParser({required ScriptsSource source}) : _source = source;

  @override
  List<CommandExecuted> listCommands() {
    var scripts = _source.getScripts();
    final context = Context.root(scripts);
    return _listCommands(context: context).toList();
  }

  Iterable<CommandExecuted> _listCommands({
    required Context context,
  }) sync* {
    final current = context.current;

    if (current is String) {
      if (context.isRoot) {
        // todo: load file with scripts
        /// Do not consider hooks
      } else if (context.key == ScriptsParser.scriptKey ||
          (context.key != null && !ScriptsParser.isSpecialKey(context.key!))) {
        yield CommandExecuted(
          command: current,
          context: context,
        );
      }
    } else if (current is Map) {
      if (_hasScriptKey(current)) {
        final script = current[ScriptsParser.scriptKey];
        final description = current[ScriptsParser.descriptionKey];
        if (script is String) {
          yield CommandExecuted(
            command: script,
            context: context,
            description: description,
          );
        } else if (script is Map) {
          final platformKey = '\$${Platform.operatingSystem}';
          final command =
              script[platformKey] ?? script[ScriptsParser.defaultScriptKey];
          if (command is! String) {
            yield CommandExecuted(
              command: '-',
              context: context,
              description: description,
              errors: [
                'No platform script key for the command: "${context.path}". '
                    'Consider adding the key for the current '
                    'platform: "$platformKey" or the default script '
                    'key: "${ScriptsParser.defaultScriptKey}".',
              ],
            );
          } else {
            yield CommandExecuted(
              command: command,
              context: context,
              description: description,
            );
          }
        }
      } else {
        for (final key in current.keys) {
          yield* _listCommands(context: context.next(key));
        }
      }
    } else {
      yield CommandExecuted(
        command: current.toString(),
        context: context,
        errors: [
          'Invalid command. Cannot use type '
              '${current.runtimeType} ($current) as a command.',
        ],
      );
    }
  }

  @override
  List<ExecutionEvent> getCommandsToExecute(List<String> arguments) {
    var scripts = _source.getScripts();
    var context = Context.root(scripts);
    // If command is not specified, fallback to run
    if (arguments.isEmpty) {
      context = context.next('run');
    }

    final events = <ExecutionEvent>{};
    for (final event
        in _getCommandsToExecute(context: context, arguments: arguments)) {
      final added = events.add(event);
      if (!added) {
        throw ScriptParserException(
          'Script cycle detected: ${[
            ...events.map((e) => e.path),
            event.path
          ].join(' → ')}',
        );
      }
    }

    return events.toList();
  }

  Iterable<ExecutionEvent> _getCommandsToExecute({
    required Context context,
    required List<String> arguments,
  }) sync* {
    final current = context.current;

    if (current == null) {
      // no command
      return;
    } else if (current is String) {
      if (context.isRoot) {
        // todo Load file with scripts
        throw RpsException(
          'The root key "scripts" cannot contain commands.',
        );
      } else {
        yield* _handleCommand(
          command: current,
          context: context,
          arguments: arguments,
        );
      }
    } else if (current is Map) {
      // if it is a Map, it may contain hooks.
      yield* _handleHooks(context, () sync* {
        if (_hasScriptKey(current)) {
          final script = current[ScriptsParser.scriptKey];
          if (script is String) {
            yield* _handleCommand(
              command: script,
              context: context,
              arguments: arguments,
            );
          } else if (script is Map) {
            final platformKey = '\$${Platform.operatingSystem}';
            final command =
                script[platformKey] ?? script[ScriptsParser.defaultScriptKey];
            if (command is! String) {
              throw RpsException(
                'No platform script key for the command: "${context.path}". '
                'Consider adding the key for the current '
                'platform: "$platformKey" or the default script '
                'key: "${ScriptsParser.defaultScriptKey}".',
              );
            } else {
              yield* _handleCommand(
                command: command,
                context: context,
                arguments: arguments,
              );
            }
          }
        } else {
          final nextKey = arguments.firstOrNull;
          if (nextKey == null) {
            throw RpsException(
              'Missing script. Command: "${context.path}" '
              'is not a full path.',
            );
          } else {
            final remainingArguments = arguments.skip(1).toList();
            yield* _getCommandsToExecute(
              context: context.next(nextKey),
              arguments: remainingArguments,
            );
          }
        }
      });
    } else {
      throw RpsException(
        'Invalid command. Cannot use type '
        '${current.runtimeType} ($current) as a command.',
      );
    }
  }

  Iterable<ExecutionEvent> _handleHooks(
    Context context,
    Iterable<ExecutionEvent> Function() handler,
  ) sync* {
    final current = context.current;
    final beforeHook = current[ScriptsParser.beforeKey];
    if (beforeHook is String) {
      final hookContext = context.next(ScriptsParser.beforeKey);
      yield HookExecuted(
        command: beforeHook,
        context: hookContext,
        name: 'before',
      );
      yield* _handleCommand(
        isHook: true,
        command: beforeHook,
        context: hookContext,
        // arguments are not passed to to the hooks
        arguments: null,
      );
    }

    yield* handler();

    final afterHook = current[ScriptsParser.afterKey];
    if (afterHook is String) {
      final hookContext = context.next(ScriptsParser.afterKey);
      yield HookExecuted(
        command: afterHook,
        context: hookContext,
        name: 'after',
      );
      yield* _handleCommand(
        command: afterHook,
        context: hookContext,
        // arguments are not passed to to the hooks
        arguments: null,
        isHook: true,
      );
    }
  }

  Iterable<ExecutionEvent> _handleCommand({
    required Context context,
    required String command,
    List<String>? arguments,
    bool isHook = false,
  }) sync* {
    if (command.startsWith(r'rps ')) {
      final referencedCommand = command.substring(4);

      yield CommandReferenced(
        command: referencedCommand,
        context: context,
        label: context.key!,
        isHook: isHook,
      );

      /// Ref should start from root.
      yield* _getCommandsToExecute(
        context: Context(
          key: null,
          parent: context,
          isBase: true,
          current: context.root.current,
        ),
        arguments: [
          ...referencedCommand.split(RegExp(r'\s+')),
          ...?arguments,
        ],
      );
    } else {
      yield CommandExecuted(
        command: command,
        context: context,
        arguments: arguments,
        isHook: isHook,
      );
    }
  }

  bool _hasScriptKey(Map scripts) {
    return scripts.containsKey(ScriptsParser.scriptKey);
  }
}
