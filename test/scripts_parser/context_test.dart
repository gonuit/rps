import 'package:rps/rps.dart';
import 'package:test/test.dart';

void main() {
  group('Context', () {
    test('root has no parent', () {
      final ctx = Context.root({'a': 'b'});
      expect(ctx.isRoot, isTrue);
      expect(ctx.parent, isNull);
      expect(ctx.isBase, isTrue);
    });

    test('path builds from root', () {
      final root = Context.root({
        'build': {'android': 'cmd'}
      });
      final child = root.next('build');
      final grandchild = child.next('android');

      expect(grandchild.path, equals(['build', 'android']));
    });

    test('root path is empty', () {
      final root = Context.root({});
      expect(root.path, isEmpty);
    });

    test('next creates child with correct current', () {
      final root = Context.root({'key': 'value'});
      final child = root.next('key');

      expect(child.current, equals('value'));
      expect(child.key, equals('key'));
      expect(child.isBase, isFalse);
    });

    test('basePath stops at base node', () {
      final root = Context.root({
        'a': {'b': 'c'}
      });
      final base = Context(
        key: 'ref',
        parent: root,
        isBase: true,
        current: root.current,
      );
      final child = Context(
        key: 'a',
        parent: base,
        isBase: false,
        current: (root.current as Map)['a'],
      );

      expect(child.basePath, equals(['a']));
    });

    test('root getter returns topmost context', () {
      final root = Context.root({});
      final child = root.next('a');
      expect(child.root, same(root));
    });

    test('toBase extracts subtree', () {
      final root = Context.root({
        'a': {'b': 'c'}
      });
      final a = root.next('a');
      final b = a.next('b');
      final based = b.toBase();

      expect(based.key, equals('b'));
      expect(based.isBase, isFalse);
    });
  });
}
