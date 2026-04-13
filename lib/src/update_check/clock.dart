/// Abstraction over time so time-dependent logic is unit-testable.
abstract interface class Clock {
  /// Returns the current date and time.
  DateTime now();
}

/// A [Clock] backed by [DateTime.now].
class SystemClock implements Clock {
  /// Creates a [SystemClock].
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
