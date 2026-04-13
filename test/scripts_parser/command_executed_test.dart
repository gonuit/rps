import 'package:rps/rps.dart';
import 'package:test/test.dart';

void main() {
  group('CommandExecuted', () {
    test('compile returns command with appended arguments', () {
      final ctx = Context.root({'echo': 'echo hello'});
      final cmd = CommandExecuted(
        command: 'echo hello',
        context: ctx.next('echo'),
        arguments: ['world'],
      );
      expect(cmd.compile(), equals('echo hello world'));
    });

    test('compile fills positional arguments', () {
      final ctx = Context.root({r'greet': r'echo ${0} ${1}'});
      final cmd = CommandExecuted(
        command: r'echo ${0} ${1}',
        context: ctx.next('greet'),
        arguments: ['hello', 'world'],
      );
      expect(cmd.compile(), equals('echo hello world'));
    });

    test('path joins context keys', () {
      final root = Context.root({
        'a': {'b': 'cmd'}
      });
      final cmd = CommandExecuted(
        command: 'cmd',
        context: root.next('a').next('b'),
      );
      expect(cmd.path, equals('a b'));
    });

    test('errorMessage returns null when no errors', () {
      final ctx = Context.root({'x': 'echo'});
      final cmd = CommandExecuted(
        command: 'echo',
        context: ctx.next('x'),
      );
      expect(cmd.errorMessage, isNull);
    });

    test('errorMessage returns joined errors', () {
      final ctx = Context.root({'x': 'echo'});
      final cmd = CommandExecuted(
        command: 'echo',
        context: ctx.next('x'),
        errors: ['err1', 'err2'],
      );
      expect(cmd.errorMessage, equals('err1\nerr2'));
    });

    test('compile throws on errors', () {
      final ctx = Context.root({'x': 'echo'});
      final cmd = CommandExecuted(
        command: 'echo',
        context: ctx.next('x'),
        errors: ['bad command'],
      );
      expect(() => cmd.compile(), throwsA(isA<RpsException>()));
    });

    test('compile throws when positional arg used in hook', () {
      final ctx = Context.root({r'x': r'echo ${0}'});
      final cmd = CommandExecuted(
        command: r'echo ${0}',
        context: ctx.next('x'),
        arguments: ['val'],
        isHook: true,
      );
      expect(() => cmd.compile(), throwsA(isA<RpsException>()));
    });

    test('equality based on command and path', () {
      final ctx = Context.root({'x': 'echo'});
      final a = CommandExecuted(command: 'echo', context: ctx.next('x'));
      final b = CommandExecuted(command: 'echo', context: ctx.next('x'));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('description is stored', () {
      final ctx = Context.root({'x': 'echo'});
      final cmd = CommandExecuted(
        command: 'echo',
        context: ctx.next('x'),
        description: 'prints hello',
      );
      expect(cmd.description, equals('prints hello'));
    });

    test('isHook defaults to false', () {
      final ctx = Context.root({'x': 'echo'});
      final cmd = CommandExecuted(command: 'echo', context: ctx.next('x'));
      expect(cmd.isHook, isFalse);
    });

    test('getScriptArguments parses positional args', () {
      final args = CommandExecuted.getScriptArguments(r'echo ${0} ${1}');
      expect(args.length, equals(2));
      expect(args[0].index, equals(0));
      expect(args[1].index, equals(1));
    });

    test('getScriptArguments throws on gaps', () {
      expect(
        () => CommandExecuted.getScriptArguments(r'echo ${0} ${2}'),
        throwsA(isA<RpsException>()),
      );
    });

    test('compile quotes arguments with spaces', () {
      final ctx = Context.root({'x': 'echo'});
      final cmd = CommandExecuted(
        command: 'echo',
        context: ctx.next('x'),
        arguments: ['hello world'],
      );
      expect(cmd.compile(), equals('echo "hello world"'));
    });

    test('compile escapes quotes in arguments', () {
      final ctx = Context.root({'x': 'echo'});
      final cmd = CommandExecuted(
        command: 'echo',
        context: ctx.next('x'),
        arguments: ['he"llo'],
      );
      expect(cmd.compile(), contains(r'he\"llo'));
    });
  });

  group('PositionalArgument', () {
    test('equality', () {
      final a = PositionalArgument(r'${0}', 0);
      final b = PositionalArgument(r'${0}', 0);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality', () {
      final a = PositionalArgument(r'${0}', 0);
      final b = PositionalArgument(r'${1}', 1);
      expect(a, isNot(equals(b)));
    });
  });

  group('CommandReferenced', () {
    test('equality based on command, path, and label', () {
      final ctx = Context.root({'x': 'rps echo'});
      final a = CommandReferenced(
        command: 'echo',
        context: ctx.next('x'),
        label: 'x',
      );
      final b = CommandReferenced(
        command: 'echo',
        context: ctx.next('x'),
        label: 'x',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('HookExecuted', () {
    test('equality based on command, path, and name', () {
      final ctx = Context.root({r'$before': 'echo hi'});
      final a = HookExecuted(
        command: 'echo hi',
        context: ctx.next(r'$before'),
        name: 'before',
      );
      final b = HookExecuted(
        command: 'echo hi',
        context: ctx.next(r'$before'),
        name: 'before',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
