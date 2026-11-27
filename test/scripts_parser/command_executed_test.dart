import 'package:rps/rps.dart';
import 'package:test/test.dart';

void main() {
  group('CommandExecuted', () {
    test('compile returns command with appended arguments', () {
      final ctx = Context.root();
      final cmd = CommandExecuted(
        command: 'echo hello',
        context: ctx.next('echo'),
        arguments: ['world'],
      );
      expect(cmd.compile(), equals('echo hello world'));
    });

    test('compile fills positional arguments', () {
      final ctx = Context.root();
      final cmd = CommandExecuted(
        command: r'echo ${0} ${1}',
        context: ctx.next('greet'),
        arguments: ['hello', 'world'],
      );
      expect(cmd.compile(), equals('echo hello world'));
    });

    test('path joins context keys', () {
      final root = Context.root();
      final cmd = CommandExecuted(
        command: 'cmd',
        context: root.next('a').next('b'),
      );
      expect(cmd.path, equals('a b'));
    });

    test('errorMessage returns null when no errors', () {
      final ctx = Context.root();
      final cmd = CommandExecuted(
        command: 'echo',
        context: ctx.next('x'),
      );
      expect(cmd.errorMessage, isNull);
    });

    test('compile throws when the positional arguments have a gap', () {
      final ctx = Context.root();
      final cmd = CommandExecuted(
        command: r'echo ${1}',
        context: ctx.next('x'),
        arguments: ['a', 'b'],
      );
      expect(
        cmd.errorMessage,
        equals(r'The script defines unused positional argument(s): ${0}'),
      );
      expect(() => cmd.compile(), throwsA(isA<RpsConfigException>()));
    });

    test('compile throws when positional arg used in hook', () {
      final ctx = Context.root();
      final cmd = CommandExecuted(
        command: r'echo ${0}',
        context: ctx.next('x'),
        arguments: ['val'],
        isHook: true,
      );
      expect(() => cmd.compile(), throwsA(isA<RpsException>()));
    });

    test('equality based on command and path', () {
      final ctx = Context.root();
      final a = CommandExecuted(command: 'echo', context: ctx.next('x'));
      final b = CommandExecuted(command: 'echo', context: ctx.next('x'));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('isHook defaults to false', () {
      final ctx = Context.root();
      final cmd = CommandExecuted(command: 'echo', context: ctx.next('x'));
      expect(cmd.isHook, isFalse);
    });

    test('PositionalArgument.parse reads positional args', () {
      final args = PositionalArgument.parse(r'echo ${0} ${1}');
      expect(args.length, equals(2));
      expect(args[0].index, equals(0));
      expect(args[1].index, equals(1));
    });

    test('PositionalArgument.parse throws on gaps', () {
      expect(
        () => PositionalArgument.parse(r'echo ${0} ${2}'),
        throwsA(isA<RpsException>()),
      );
    });

    test('compile quotes arguments with spaces', () {
      final ctx = Context.root();
      final cmd = CommandExecuted(
        command: 'echo',
        context: ctx.next('x'),
        arguments: ['hello world'],
      );
      expect(cmd.compile(), equals("echo 'hello world'"));
    });

    test('compile passes quotes in arguments literally', () {
      final ctx = Context.root();
      final cmd = CommandExecuted(
        command: 'echo',
        context: ctx.next('x'),
        arguments: ['he"llo', "it's"],
      );
      expect(cmd.compile(), equals('echo \'he"llo\' ' r"'it'\''s'"));
    });

    test('compile quotes shell metacharacters and keeps empty arguments', () {
      final ctx = Context.root();
      final cmd = CommandExecuted(
        command: 'echo',
        context: ctx.next('x'),
        arguments: ['a&b', r'$HOME', '', 'plain-arg=1'],
      );
      expect(cmd.compile(), equals(r"echo 'a&b' '$HOME' '' plain-arg=1"));
    });

    test('compile quotes only arguments after positional ones', () {
      final ctx = Context.root();
      final cmd = CommandExecuted(
        command: r'echo "${0}"',
        context: ctx.next('x'),
        arguments: ['a b', 'c d'],
      );
      expect(cmd.compile(), equals("echo \"a b\" 'c d'"));
    });

    test('compile uses the given shell syntax', () {
      final ctx = Context.root();
      final cmd = CommandExecuted(
        command: 'echo',
        context: ctx.next('x'),
        arguments: ["it's"],
      );
      expect(
        cmd.compile(shell: const PowerShell()),
        equals("echo 'it''s'"),
      );
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
      final ctx = Context.root();
      final a = CommandReferenced(
        command: 'echo',
        context: ctx.next('x'),
      );
      final b = CommandReferenced(
        command: 'echo',
        context: ctx.next('x'),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
