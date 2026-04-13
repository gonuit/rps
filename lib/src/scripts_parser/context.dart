import 'package:collection/collection.dart';

/// Represents a node in the script resolution tree.
class Context {
  /// The value at this node (may be a String, Map, or null).
  final dynamic current;

  /// The key used to reach this node from its parent.
  final String? key;

  /// Parent context of this node.
  final Context? parent;

  /// Each time the reference is triggered,
  /// the context starts from the `base` node.
  ///
  /// It has a [current] state equal to `root`, but is not a terminating node
  /// because it maintains the context between references.
  ///
  /// `root` - is the first node of the execution.
  /// `base` - is the first node of execution or after reference.
  final bool isBase;

  /// Initial context node. The entry point of the run command.
  bool get isRoot => parent == null;

  /// Creates a [Context].
  Context({
    required this.key,
    required this.parent,
    required this.current,
    required this.isBase,
  });

  /// Initial context node. The entry point of the run command.
  Context.root(this.current)
      : parent = null,
        isBase = true,
        key = null;

  /// Returns the full key path from root to this node.
  List<String> get path {
    final path = <String>[];

    Context? context = this;
    while (context != null) {
      final key = context.key;
      if (key != null) {
        path.add(key);
      }
      context = context.parent;
    }
    return path.reversed.toList();
  }

  /// Returns the key path from the nearest base node to this node.
  List<String> get basePath {
    final path = <String>[];

    Context? context = this;
    while (context != null && !context.isBase) {
      final key = context.key;
      if (key != null) {
        path.add(key);
      }
      context = context.parent;
    }
    return path.reversed.toList();
  }

  /// Get the initial context node from the context tree.
  Context get root {
    Context context = this;
    while (context.parent != null) {
      context = context.parent!;
    }
    return context;
  }

  /// Returns a child context for the given [key].
  Context next(String key) {
    return Context(
      key: key,
      parent: this,
      isBase: false,
      current: current[key],
    );
  }

  /// Takes a portion of the context tree
  /// from the current node (leaf) to the base.
  Context toBase() {
    final stack = <Context>[];
    Context context = this;
    while (context.parent != null) {
      stack.add(context);
      if (context.isBase) break;
      context = context.parent!;
    }

    Context? getParent(List<Context> stack) {
      final context = stack.firstOrNull;
      if (context == null) return null;
      return Context(
        current: context.current,
        isBase: stack.length == 1,
        key: context.key,
        parent: getParent(stack.skip(1).toList()),
      );
    }

    return getParent(stack)!;
  }
}
