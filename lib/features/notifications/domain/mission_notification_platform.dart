final class MissionNotificationRequest {
  const MissionNotificationRequest({
    required this.scheduleId,
    required this.notifyAtUtcMs,
    required this.soundEnabled,
    this.systemNotificationId,
  });

  final String scheduleId;
  final int notifyAtUtcMs;
  final bool soundEnabled;
  final int? systemNotificationId;
}

abstract interface class MissionNotificationPlatform {
  Future<bool> requestPermission();

  Future<int> schedule(MissionNotificationRequest request);

  Future<int> deliverIfNeeded(MissionNotificationRequest request);

  Future<void> cancel(int systemNotificationId);
}
