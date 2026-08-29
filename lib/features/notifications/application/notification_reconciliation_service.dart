import 'package:drift/drift.dart';

import '../../../infrastructure/database/app_database.dart';
import '../../../infrastructure/database/daos/notification_dao.dart';
import '../../../infrastructure/database/daos/settings_dao.dart';
import '../../settings/domain/models/app_preferences.dart';
import '../domain/mission_notification_platform.dart';
import '../domain/reminder_preferences.dart';
import '../domain/reminder_preferences_repository.dart';

final class NotificationReconciliationReport {
  const NotificationReconciliationReport({
    required this.permissionGranted,
    required this.scheduled,
    required this.fired,
    required this.cancelled,
    required this.failed,
  });

  final bool permissionGranted;
  final int scheduled;
  final int fired;
  final int cancelled;
  final int failed;
}

final class NotificationReconciliationService {
  const NotificationReconciliationService({
    required NotificationDao notificationDao,
    required SettingsDao settingsDao,
    required ReminderPreferencesRepository reminderPreferencesRepository,
    required MissionNotificationPlatform platform,
    required DateTime Function() nowUtc,
  }) : _notificationDao = notificationDao,
       _settingsDao = settingsDao,
       _reminderPreferencesRepository = reminderPreferencesRepository,
       _platform = platform,
       _nowUtc = nowUtc;

  final NotificationDao _notificationDao;
  final SettingsDao _settingsDao;
  final ReminderPreferencesRepository _reminderPreferencesRepository;
  final MissionNotificationPlatform _platform;
  final DateTime Function() _nowUtc;

  Future<NotificationReconciliationReport> reconcile() async {
    final int nowUtcMs = _nowUtc().toUtc().millisecondsSinceEpoch;
    final AppSetting settings = await _settingsDao.getSettings();
    final bool showNotificationDetails =
        await _settingsDao.getMetadata(
          AppPreferences.showNotificationDetailsMetadataKey,
        ) ==
        '1';
    ReminderPreferences reminderPreferences = ReminderPreferences.defaults;
    final preferencesResult = await _reminderPreferencesRepository.load();
    preferencesResult.fold<void>(
      onSuccess: (ReminderPreferences value) => reminderPreferences = value,
      onFailure: (_) {},
    );
    final List<NotificationSchedule> candidates = await _notificationDao
        .findReconciliationCandidates();
    final terminal = candidates.where(
      (item) => const <String>{'CANCELLED', 'FAILED'}.contains(item.status),
    );
    final open = candidates.where(
      (item) => const <String>{'PENDING', 'SCHEDULED'}.contains(item.status),
    );

    int cancelled = 0;
    int failed = 0;
    for (final schedule in terminal) {
      try {
        await _cancelAndClear(schedule, nowUtcMs);
        cancelled++;
      } on Object {
        failed++;
      }
    }

    if (settings.missionNotifications == 0) {
      for (final schedule in open) {
        try {
          final int? systemId = schedule.systemNotificationId;
          if (systemId != null) {
            await _platform.cancel(systemId);
          }
          await _notificationDao.transitionStatus(
            scheduleId: schedule.id,
            allowedCurrentStatuses: const <String>{'PENDING', 'SCHEDULED'},
            nextStatus: 'PENDING',
            updatedAtUtcMs: nowUtcMs,
            systemNotificationId: const Value<int?>(null),
          );
          cancelled++;
        } on Object {
          failed++;
        }
      }
      return NotificationReconciliationReport(
        permissionGranted: false,
        scheduled: 0,
        fired: 0,
        cancelled: cancelled,
        failed: failed,
      );
    }

    if (open.isEmpty) {
      return NotificationReconciliationReport(
        permissionGranted: true,
        scheduled: 0,
        fired: 0,
        cancelled: cancelled,
        failed: failed,
      );
    }

    final bool permissionGranted = await _platform.requestPermission();
    if (!permissionGranted) {
      return NotificationReconciliationReport(
        permissionGranted: false,
        scheduled: 0,
        fired: 0,
        cancelled: cancelled,
        failed: failed,
      );
    }

    int scheduledCount = 0;
    int fired = 0;
    for (final schedule in open) {
      final int deliveryAtUtcMs = reminderPreferences.deliveryAtUtcMs(
        schedule.notifyAt,
      );
      final String? missionTitle = showNotificationDetails
          ? await _notificationDao.findMissionTitle(schedule.missionId)
          : null;
      final request = MissionNotificationRequest(
        scheduleId: schedule.id,
        notifyAtUtcMs: deliveryAtUtcMs,
        soundEnabled:
            settings.soundEnabled != 0 &&
            !reminderPreferences.isQuietAtUtcMs(deliveryAtUtcMs),
        showDetails:
            showNotificationDetails && missionTitle?.trim().isNotEmpty == true,
        missionTitle: missionTitle?.trim(),
        systemNotificationId: schedule.systemNotificationId,
      );
      try {
        if (deliveryAtUtcMs <= nowUtcMs) {
          await _platform.deliverIfNeeded(request);
          await _notificationDao.transitionStatus(
            scheduleId: schedule.id,
            allowedCurrentStatuses: const <String>{'PENDING', 'SCHEDULED'},
            nextStatus: 'FIRED',
            updatedAtUtcMs: nowUtcMs,
            systemNotificationId: const Value<int?>(null),
          );
          fired++;
        } else {
          final int systemId = await _platform.schedule(request);
          await _notificationDao.transitionStatus(
            scheduleId: schedule.id,
            allowedCurrentStatuses: const <String>{'PENDING', 'SCHEDULED'},
            nextStatus: 'SCHEDULED',
            updatedAtUtcMs: nowUtcMs,
            systemNotificationId: Value<int?>(systemId),
          );
          scheduledCount++;
        }
      } on Object {
        failed++;
      }
    }

    return NotificationReconciliationReport(
      permissionGranted: true,
      scheduled: scheduledCount,
      fired: fired,
      cancelled: cancelled,
      failed: failed,
    );
  }

  Future<void> _cancelAndClear(
    NotificationSchedule schedule,
    int nowUtcMs,
  ) async {
    final int? systemId = schedule.systemNotificationId;
    if (systemId == null) {
      return;
    }
    await _platform.cancel(systemId);
    await _notificationDao.transitionStatus(
      scheduleId: schedule.id,
      allowedCurrentStatuses: <String>{schedule.status},
      nextStatus: schedule.status,
      updatedAtUtcMs: nowUtcMs,
      systemNotificationId: const Value<int?>(null),
    );
  }
}
