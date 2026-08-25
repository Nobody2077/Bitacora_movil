/// Civil clock used only for persisted throttling across process restarts.
abstract interface class AccessClock {
  int nowEpochMillis();
}

final class SystemAccessClock implements AccessClock {
  const SystemAccessClock();

  @override
  int nowEpochMillis() => DateTime.now().millisecondsSinceEpoch;
}
