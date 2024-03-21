import 'package:collection/collection.dart';

class Context {
  final dynamic current;
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
