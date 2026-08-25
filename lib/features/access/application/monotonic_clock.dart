abstract interface class MonotonicClock {
  Duration now();
}

final class StopwatchMonotonicClock implements MonotonicClock {
  StopwatchMonotonicClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  Duration now() => _stopwatch.elapsed;
}
