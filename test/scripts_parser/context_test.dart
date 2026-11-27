import 'package:rps/rps.dart';
import 'package:test/test.dart';

void main() {
  group('Context', () {
    test('root has no parent and an empty path', () {
      final root = Context.root();

      expect(root.parent, isNull);
      expect(root.isBase, isTrue);
      expect(root.path, isEmpty);
      expect(root.basePath, isEmpty);
    });

    test('next creates a child with the key', () {
      final child = Context.root().next('build').next('android');

      expect(child.key, equals('android'));
      expect(child.isBase, isFalse);
      expect(child.path, equals(['build', 'android']));
      expect(child.basePath, equals(['build', 'android']));
    });

    test('a reference starts a new base path and keeps the full path', () {
      final referenced =
          Context.root().next('alias').reference().next('build').next('apk');

      expect(referenced.basePath, equals(['build', 'apk']));
      expect(referenced.path, equals(['alias', 'build', 'apk']));
    });
  });
}
