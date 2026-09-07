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
    this.bootMirrorSynced = true,
    this.dailySummaryScheduled = false,
  });

  final bool permissionGranted;
  final int scheduled;
  final int fired;
  final int cancelled;
  final int failed;

  /// Si el espejo que permite reponer alarmas tras un reinicio quedó al día.
  ///
  /// Se expone en vez de tragarse el fallo: un espejo desincronizado no rompe
  /// nada hoy, pero significa que el próximo reinicio pierde recordatorios.
  final bool bootMirrorSynced;

  /// Si quedó programado el resumen diario de la próxima ocurrencia.
  final bool dailySummaryScheduled;
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

  /// Identificador de sistema fijo para el resumen diario.
  ///
  /// Constante a propósito: cada día reemplaza la notificación del anterior en
  /// vez de apilarse, y permite cancelarlo sin recordar qué día se programó.
  static const int dailySummarySystemNotificationId = 747474747;

  final NotificationDao _notificationDao;
  final SettingsDao _settingsDao;
  final ReminderPreferencesRepository _reminderPreferencesRepository;
  final MissionNotificationPlatform _platform;
  final DateTime Function() _nowUtc;

  /// Identificador del resumen de un día civil concreto.
  ///
  /// Lleva la fecha porque Android descarta entregas repetidas del mismo
  /// `scheduleId`. Con un identificador fijo, el resumen sonaría el primer día
  /// y nunca más.
  static String dailySummaryScheduleId(int occurrenceUtcMs) {
    final DateTime local = DateTime.fromMillisecondsSinceEpoch(
      occurrenceUtcMs,
      isUtc: true,
    ).toLocal();
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    return 'daily-summary-${local.year}-$month-$day';
  }

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

    // El espejo de arranque. La consulta no tiene ventana temporal, así que
    // `open` es el conjunto completo de alarmas vivas y el espejo se puede
    // reemplazar entero en cada pasada. Una lista vacía lo borra.
    final List<MissionNotificationMirrorEntry> mirror =
        <MissionNotificationMirrorEntry>[];

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
      await _cancelDailySummary();
      return _withBootMirror(
        NotificationReconciliationReport(
          permissionGranted: false,
          scheduled: 0,
          fired: 0,
          cancelled: cancelled,
          failed: failed,
        ),
        mirror,
      );
    }

    final bool needsPermission =
        open.isNotEmpty || reminderPreferences.dailySummaryEnabled;
    if (!needsPermission) {
      await _cancelDailySummary();
      return _withBootMirror(
        NotificationReconciliationReport(
          permissionGranted: true,
          scheduled: 0,
          fired: 0,
          cancelled: cancelled,
          failed: failed,
        ),
        mirror,
      );
    }

    final bool permissionGranted = await _platform.requestPermission();
    if (!permissionGranted) {
      return _withBootMirror(
        NotificationReconciliationReport(
          permissionGranted: false,
          scheduled: 0,
          fired: 0,
          cancelled: cancelled,
          failed: failed,
        ),
        mirror,
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
      final bool soundEnabled =
          settings.soundEnabled != 0 &&
          !reminderPreferences.isQuietAtUtcMs(deliveryAtUtcMs);
      final bool showDetails =
          showNotificationDetails && missionTitle?.trim().isNotEmpty == true;
      final request = MissionNotificationRequest(
        scheduleId: schedule.id,
        notifyAtUtcMs: deliveryAtUtcMs,
        soundEnabled: soundEnabled,
        showDetails: showDetails,
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
          // Sin el título: el espejo vive fuera de la base cifrada.
          mirror.add(
            MissionNotificationMirrorEntry(
              scheduleId: schedule.id,
              systemNotificationId: systemId,
              notifyAtUtcMs: deliveryAtUtcMs,
              soundEnabled: soundEnabled,
              showDetails: showDetails,
            ),
          );
          scheduledCount++;
        }
      } on Object {
        failed++;
      }
    }

    bool summaryScheduled = false;
    if (reminderPreferences.dailySummaryEnabled) {
      try {
        summaryScheduled = await _scheduleDailySummary(
          preferences: reminderPreferences,
          settings: settings,
          nowUtcMs: nowUtcMs,
          mirror: mirror,
        );
        if (summaryScheduled) {
          scheduledCount++;
        }
      } on Object {
        failed++;
      }
    } else {
      await _cancelDailySummary();
    }

    return _withBootMirror(
      NotificationReconciliationReport(
        permissionGranted: true,
        scheduled: scheduledCount,
        fired: fired,
        cancelled: cancelled,
        failed: failed,
        dailySummaryScheduled: summaryScheduled,
      ),
      mirror,
    );
  }

  /// Programa la próxima ocurrencia del resumen diario.
  ///
  /// El recuento se calcula **aquí**, con la aplicación desbloqueada, y viaja
  /// hasta la alarma ya convertido en texto. El receiver que la entrega no
  /// puede abrir la base cifrada (ADR-002), así que no hay otra forma. La
  /// consecuencia aceptada es que el número es una foto del último uso de la
  /// aplicación, no del amanecer.
  Future<bool> _scheduleDailySummary({
    required ReminderPreferences preferences,
    required AppSetting settings,
    required int nowUtcMs,
    required List<MissionNotificationMirrorEntry> mirror,
  }) async {
    final int occurrenceUtcMs = preferences.nextSummaryUtcMs(nowUtcMs);
    final DateTime occurrenceLocal = DateTime.fromMillisecondsSinceEpoch(
      occurrenceUtcMs,
      isUtc: true,
    ).toLocal();
    final DateTime dayStartLocal = DateTime(
      occurrenceLocal.year,
      occurrenceLocal.month,
      occurrenceLocal.day,
    );
    final DateTime dayEndLocal = DateTime(
      occurrenceLocal.year,
      occurrenceLocal.month,
      occurrenceLocal.day + 1,
    );
    final int missions = await _notificationDao.countOpenMissionsBetween(
      fromUtcMs: dayStartLocal.toUtc().millisecondsSinceEpoch,
      toUtcMs: dayEndLocal.toUtc().millisecondsSinceEpoch,
    );
    final String scheduleId = dailySummaryScheduleId(occurrenceUtcMs);
    final bool soundEnabled =
        settings.soundEnabled != 0 &&
        !preferences.isQuietAtUtcMs(occurrenceUtcMs);
    await _platform.schedule(
      MissionNotificationRequest(
        scheduleId: scheduleId,
        notifyAtUtcMs: occurrenceUtcMs,
        soundEnabled: soundEnabled,
        showDetails: false,
        contentText: dailySummaryText(missions),
        systemNotificationId: dailySummarySystemNotificationId,
        kind: MissionNotificationKind.dailySummary,
      ),
    );
    mirror.add(
      MissionNotificationMirrorEntry(
        scheduleId: scheduleId,
        systemNotificationId: dailySummarySystemNotificationId,
        notifyAtUtcMs: occurrenceUtcMs,
        soundEnabled: soundEnabled,
        showDetails: false,
        kind: MissionNotificationKind.dailySummary,
      ),
    );
    return true;
  }

  static String dailySummaryText(int missions) => switch (missions) {
    <= 0 => 'Hoy no tienes misiones programadas.',
    1 => 'Hoy tienes 1 misión.',
    _ => 'Hoy tienes $missions misiones.',
  };

  Future<void> _cancelDailySummary() async {
    try {
      await _platform.cancel(dailySummarySystemNotificationId);
    } on Object {
      // Cancelar algo que quizá no estaba programado no es un fallo.
    }
  }

  Future<NotificationReconciliationReport> _withBootMirror(
    NotificationReconciliationReport report,
    List<MissionNotificationMirrorEntry> mirror,
  ) async {
    try {
      await _platform.syncBootMirror(mirror);
      return report;
    } on Object {
      return NotificationReconciliationReport(
        permissionGranted: report.permissionGranted,
        scheduled: report.scheduled,
        fired: report.fired,
        cancelled: report.cancelled,
        failed: report.failed,
        bootMirrorSynced: false,
        dailySummaryScheduled: report.dailySummaryScheduled,
      );
    }
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
