import 'package:flutter/services.dart';

import '../domain/mission_notification_platform.dart';

final class MethodChannelMissionNotificationPlatform
    implements MissionNotificationPlatform {
  const MethodChannelMissionNotificationPlatform();

  static const MethodChannel _channel = MethodChannel(
    'com.jcyq.bitacorarpg/mission_notifications',
  );

  @override
  Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestPermission') ?? false;

  @override
  Future<int> schedule(MissionNotificationRequest request) async {
    final int? systemId = await _channel.invokeMethod<int>(
      'schedule',
      _arguments(request),
    );
    if (systemId == null) {
      throw PlatformException(
        code: 'NOTIFICATION_SCHEDULE_FAILED',
        message: 'Android did not return a notification id.',
      );
    }
    return systemId;
  }

  @override
  Future<int> deliverIfNeeded(MissionNotificationRequest request) async {
    final int? systemId = await _channel.invokeMethod<int>(
      'deliverIfNeeded',
      _arguments(request),
    );
    if (systemId == null) {
      throw PlatformException(
        code: 'NOTIFICATION_DELIVERY_FAILED',
        message: 'Android did not return a notification id.',
      );
    }
    return systemId;
  }

  @override
  Future<void> cancel(int systemNotificationId) => _channel.invokeMethod<void>(
    'cancel',
    <String, Object>{'systemNotificationId': systemNotificationId},
  );

  @override
  Future<void> syncBootMirror(List<MissionNotificationMirrorEntry> entries) =>
      _channel.invokeMethod<void>('syncBootMirror', <String, Object>{
        'entries': <Map<String, Object>>[
          for (final entry in entries)
            <String, Object>{
              'scheduleId': entry.scheduleId,
              'systemNotificationId': entry.systemNotificationId,
              'notifyAtUtcMs': entry.notifyAtUtcMs,
              'soundEnabled': entry.soundEnabled,
              'showDetails': entry.showDetails,
            },
        ],
      });

  Map<String, Object> _arguments(MissionNotificationRequest request) =>
      <String, Object>{
        'scheduleId': request.scheduleId,
        'notifyAtUtcMs': request.notifyAtUtcMs,
        'soundEnabled': request.soundEnabled,
        'showDetails': request.showDetails,
        if (request.missionTitle != null) 'missionTitle': request.missionTitle!,
        if (request.systemNotificationId != null)
          'systemNotificationId': request.systemNotificationId!,
      };
}
