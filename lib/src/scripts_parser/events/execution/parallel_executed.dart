import 'package:rps/rps.dart';

/// One of the commands that a script runs at the same time.
class ParallelBranch {
  /// Name shown in front of every line of the output.
  final String label;

  /// What the branch runs, in order.
  final List<ExecutionEvent> events;

  /// Creates a [ParallelBranch].
  const ParallelBranch({required this.label, required this.events});
}

/// An execution event of a script that runs several commands at the same time.
class ParallelExecuted extends ExecutionEvent {
  @override
  final Context context;

  /// The commands run at the same time.
  final List<ParallelBranch> branches;

  /// Whether the other commands are stopped when one fails.
  final bool failFast;

  @override
  String get path => context.basePath.join(' ');

  @override
  String? get command => null;

  /// Creates a [ParallelExecuted].
  ParallelExecuted({
    required this.context,
    required this.branches,
    this.failFast = true,
  });
}
