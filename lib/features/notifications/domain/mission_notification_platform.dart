final class MissionNotificationRequest {
  const MissionNotificationRequest({
    required this.scheduleId,
    required this.notifyAtUtcMs,
    required this.soundEnabled,
    required this.showDetails,
    this.missionTitle,
    this.systemNotificationId,
  });

  final String scheduleId;
  final int notifyAtUtcMs;
  final bool soundEnabled;
  final bool showDetails;
  final String? missionTitle;
  final int? systemNotificationId;
}

abstract interface class MissionNotificationPlatform {
  Future<bool> requestPermission();

  Future<int> schedule(MissionNotificationRequest request);

  Future<int> deliverIfNeeded(MissionNotificationRequest request);

  Future<void> cancel(int systemNotificationId);
}
