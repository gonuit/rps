/// Represents a node in the script resolution tree.
class Context {
  /// The key used to reach this node from its parent.
  final String? key;

  /// Parent context of this node.
  final Context? parent;

  /// Each time the reference is triggered,
  /// the context starts from the `base` node.
  ///
  /// It is not a terminating node, because it keeps the context
  /// between references.
  ///
  /// `root` - is the first node of the execution.
  /// `base` - is the first node of execution or after reference.
  final bool isBase;

  /// Creates a [Context].
  Context({
    required this.key,
    required this.parent,
    required this.isBase,
  });

  /// Initial context node. The entry point of the run command.
  Context.root()
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

  /// Returns a child context for the given [key].
  Context next(String key) {
    return Context(key: key, parent: this, isBase: false);
  }

  /// Returns the context of a script reached through a reference from here.
  Context reference() => Context(key: null, parent: this, isBase: true);
}
