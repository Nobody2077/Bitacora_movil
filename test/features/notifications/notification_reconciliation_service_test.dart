import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/notifications/application/notification_reconciliation_service.dart';
import 'package:bitacora_rpg_personal/features/notifications/data/drift_reminder_preferences_repository.dart';
import 'package:bitacora_rpg_personal/features/notifications/domain/mission_notification_platform.dart';
import 'package:bitacora_rpg_personal/features/notifications/domain/reminder_preferences.dart';
import 'package:bitacora_rpg_personal/features/settings/domain/models/app_preferences.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/notification_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/settings_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/default_seed_v1.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const int _nowMs = 1787745600000;

void main() {
  late AppDatabase database;
  late NotificationDao notificationDao;
  late SettingsDao settingsDao;
  late DriftReminderPreferencesRepository reminderPreferencesRepository;
  late _FakeNotificationPlatform platform;
  late NotificationReconciliationService service;

  setUp(() async {
    database = AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => _nowMs,
    );
    notificationDao = NotificationDao(database);
    settingsDao = SettingsDao(database);
    reminderPreferencesRepository = DriftReminderPreferencesRepository(
      settingsDao,
    );
    await reminderPreferencesRepository.save(
      ReminderPreferences.defaults.copyWith(leadMinutes: 0),
    );
    platform = _FakeNotificationPlatform();
    service = NotificationReconciliationService(
      notificationDao: notificationDao,
      settingsDao: settingsDao,
      reminderPreferencesRepository: reminderPreferencesRepository,
      platform: platform,
      nowUtc: () => DateTime.fromMillisecondsSinceEpoch(_nowMs, isUtc: true),
    );
  });

  tearDown(() => database.close());

  test('programa futuros, dispara vencidos y limpia cancelados', () async {
    await _insertSchedule(
      database,
      missionId: 'future',
      scheduleId: 'future-schedule',
      notifyAt: _nowMs + 60000,
    );
    await _insertSchedule(
      database,
      missionId: 'due',
      scheduleId: 'due-schedule',
      notifyAt: _nowMs - 1,
    );
    await _insertSchedule(
      database,
      missionId: 'cancelled',
      scheduleId: 'cancelled-schedule',
      notifyAt: _nowMs + 120000,
      status: 'CANCELLED',
      systemNotificationId: 77,
    );

    final report = await service.reconcile();

    expect(report.permissionGranted, isTrue);
    expect(report.scheduled, 1);
    expect(report.fired, 1);
    expect(report.cancelled, 1);
    expect(report.failed, 0);
    expect(platform.scheduled, <String>['future-schedule']);
    expect(platform.delivered, <String>['due-schedule']);
    // El 77 es la alarma cancelada; el otro es el resumen diario, que se
    // cancela en cada pasada mientras esté desactivado.
    expect(platform.cancelled, contains(77));
    expect(
      platform.cancelled,
      contains(
        NotificationReconciliationService.dailySummarySystemNotificationId,
      ),
    );

    final rows = await database.select(database.notificationSchedules).get();
    final byId = <String, NotificationSchedule>{
      for (final row in rows) row.id: row,
    };
    expect(byId['future-schedule']!.status, 'SCHEDULED');
    expect(byId['future-schedule']!.systemNotificationId, 1001);
    expect(byId['due-schedule']!.status, 'FIRED');
    expect(byId['due-schedule']!.systemNotificationId, isNull);
    expect(byId['cancelled-schedule']!.status, 'CANCELLED');
    expect(byId['cancelled-schedule']!.systemNotificationId, isNull);
  });

  test(
    'preferencia desactivada cancela Android y conserva intención',
    () async {
      await _insertSchedule(
        database,
        missionId: 'disabled',
        scheduleId: 'disabled-schedule',
        notifyAt: _nowMs + 60000,
        status: 'SCHEDULED',
        systemNotificationId: 81,
      );
      await settingsDao.updateSettings(
        const AppSettingsCompanion(
          missionNotifications: Value<int>(0),
          updatedAt: Value<int>(_nowMs),
        ),
      );

      final report = await service.reconcile();

      expect(report.permissionGranted, isFalse);
      expect(platform.permissionRequests, 0);
      expect(platform.cancelled, contains(81));
      final row = await database
          .select(database.notificationSchedules)
          .getSingle();
      expect(row.status, 'PENDING');
      expect(row.systemNotificationId, isNull);
    },
  );

  test('permiso denegado no pierde ni muta la intención pendiente', () async {
    platform.permissionGranted = false;
    await _insertSchedule(
      database,
      missionId: 'denied',
      scheduleId: 'denied-schedule',
      notifyAt: _nowMs + 60000,
    );

    final report = await service.reconcile();

    expect(report.permissionGranted, isFalse);
    expect(platform.permissionRequests, 1);
    final row = await database
        .select(database.notificationSchedules)
        .getSingle();
    expect(row.status, 'PENDING');
    expect(row.systemNotificationId, isNull);
  });

  test('aplica anticipación y silencia avisos dentro del horario', () async {
    final int missionStart =
        _nowMs + const Duration(minutes: 20).inMilliseconds;
    final int deliveryAt =
        missionStart - const Duration(minutes: 15).inMilliseconds;
    final DateTime deliveryLocal = DateTime.fromMillisecondsSinceEpoch(
      deliveryAt,
      isUtc: true,
    ).toLocal();
    final int deliveryMinute = deliveryLocal.hour * 60 + deliveryLocal.minute;
    await reminderPreferencesRepository.save(
      ReminderPreferences(
        leadMinutes: 15,
        quietHoursEnabled: true,
        quietStartMinutes: deliveryMinute,
        quietEndMinutes: (deliveryMinute + 1) % 1440,
        dailySummaryEnabled: false,
        dailySummaryMinutes: 6 * 60,
        genericText: ReminderPreferences.defaultGenericText,
      ),
    );
    await _insertSchedule(
      database,
      missionId: 'anticipated',
      scheduleId: 'anticipated-schedule',
      notifyAt: missionStart,
    );

    final report = await service.reconcile();

    expect(report.scheduled, 1);
    final MissionNotificationRequest request =
        platform.scheduledRequests.single;
    expect(request.notifyAtUtcMs, deliveryAt);
    expect(request.soundEnabled, isFalse);
    expect(request.showDetails, isFalse);
  });

  test('incluye el título solo cuando el usuario habilita detalles', () async {
    await settingsDao.putMetadata(
      key: AppPreferences.showNotificationDetailsMetadataKey,
      value: '1',
      updatedAtUtcMs: _nowMs,
    );
    await _insertSchedule(
      database,
      missionId: 'visible-title',
      scheduleId: 'visible-title-schedule',
      notifyAt: _nowMs + 60000,
    );

    final report = await service.reconcile();

    expect(report.scheduled, 1);
    final MissionNotificationRequest request =
        platform.scheduledRequests.single;
    expect(request.showDetails, isTrue);
    expect(request.missionTitle, 'Misión privada');
  });
  test(
    'el espejo de arranque guarda las alarmas vivas y nunca el título',
    () async {
      await settingsDao.putMetadata(
        key: AppPreferences.showNotificationDetailsMetadataKey,
        value: '1',
        updatedAtUtcMs: _nowMs,
      );
      await _insertSchedule(
        database,
        missionId: 'mirrored',
        scheduleId: 'mirrored-schedule',
        notifyAt: _nowMs + 60000,
      );
      await _insertSchedule(
        database,
        missionId: 'already-due',
        scheduleId: 'already-due-schedule',
        notifyAt: _nowMs - 1,
      );

      final report = await service.reconcile();

      expect(report.bootMirrorSynced, isTrue);
      expect(platform.mirrorSyncs, 1);
      final MissionNotificationMirrorEntry entry = platform.mirror.single;
      expect(entry.scheduleId, 'mirrored-schedule');
      expect(entry.systemNotificationId, 1001);
      expect(entry.notifyAtUtcMs, _nowMs + 60000);
      // El espejo solo lleva los cinco campos acordados; el título vive en la
      // base cifrada y no puede salir de ella ni con detalles activados.
      expect(entry.showDetails, isTrue);
      expect(
        platform.scheduledRequests.single.missionTitle,
        'Misión privada',
        reason: 'la alarma normal sí lleva título; el espejo no',
      );
    },
  );

  test('desactivar las notificaciones vacía el espejo de arranque', () async {
    await _insertSchedule(
      database,
      missionId: 'disabled-mirror',
      scheduleId: 'disabled-mirror-schedule',
      notifyAt: _nowMs + 60000,
      status: 'SCHEDULED',
      systemNotificationId: 91,
    );
    await settingsDao.updateSettings(
      const AppSettingsCompanion(
        missionNotifications: Value<int>(0),
        updatedAt: Value<int>(_nowMs),
      ),
    );

    final report = await service.reconcile();

    expect(report.bootMirrorSynced, isTrue);
    expect(platform.mirrorSyncs, 1);
    expect(platform.mirror, isEmpty);
  });

  test(
    'un espejo que falla se reporta en vez de pasar desapercibido',
    () async {
      platform.mirrorSyncFails = true;
      await _insertSchedule(
        database,
        missionId: 'mirror-fails',
        scheduleId: 'mirror-fails-schedule',
        notifyAt: _nowMs + 60000,
      );

      final report = await service.reconcile();

      expect(report.scheduled, 1, reason: 'la alarma sí quedó programada');
      expect(report.bootMirrorSynced, isFalse);
    },
  );
  group('resumen diario', () {
    Future<void> enableSummary({required int minutes}) =>
        reminderPreferencesRepository.save(
          ReminderPreferences.defaults.copyWith(
            leadMinutes: 0,
            dailySummaryEnabled: true,
            dailySummaryMinutes: minutes,
          ),
        );

    test(
      'programa la próxima ocurrencia con el recuento ya cocinado',
      () async {
        // Dos misiones abiertas y una completada el mismo día del resumen.
        final DateTime nowLocal = DateTime.fromMillisecondsSinceEpoch(
          _nowMs,
          isUtc: true,
        ).toLocal();
        final int summaryMinutes =
            (nowLocal.hour * 60 + nowLocal.minute + 30) % 1440;
        await enableSummary(minutes: summaryMinutes);
        final int occurrence = ReminderPreferences.defaults
            .copyWith(dailySummaryMinutes: summaryMinutes)
            .nextSummaryUtcMs(_nowMs);
        await _insertSchedule(
          database,
          missionId: 'summary-a',
          scheduleId: 'summary-a-schedule',
          notifyAt: occurrence + 60000,
        );
        await _insertSchedule(
          database,
          missionId: 'summary-b',
          scheduleId: 'summary-b-schedule',
          notifyAt: occurrence + 120000,
        );

        final report = await service.reconcile();

        expect(report.dailySummaryScheduled, isTrue);
        final MissionNotificationRequest summary = platform.scheduledRequests
            .singleWhere((r) => r.kind == MissionNotificationKind.dailySummary);
        expect(summary.notifyAtUtcMs, occurrence);
        expect(summary.contentText, 'Hoy tienes 2 misiones.');
        expect(
          summary.missionTitle,
          isNull,
          reason: 'el resumen no habla de ninguna misión concreta',
        );
        expect(
          summary.systemNotificationId,
          NotificationReconciliationService.dailySummarySystemNotificationId,
        );
      },
    );

    test('el identificador lleva la fecha, para que suene cada día', () {
      final int day = DateTime.utc(2026, 9, 8, 12).millisecondsSinceEpoch;
      final String id =
          NotificationReconciliationService.dailySummaryScheduleId(day);
      expect(id, startsWith('daily-summary-'));
      expect(
        id,
        isNot(
          NotificationReconciliationService.dailySummaryScheduleId(
            day + const Duration(days: 1).inMilliseconds,
          ),
        ),
        reason:
            'Android descarta entregas repetidas del mismo scheduleId; con uno '
            'fijo el resumen sonaría una sola vez',
      );
    });

    test('el resumen entra en el espejo sin el recuento', () async {
      final DateTime nowLocal = DateTime.fromMillisecondsSinceEpoch(
        _nowMs,
        isUtc: true,
      ).toLocal();
      await enableSummary(
        minutes: (nowLocal.hour * 60 + nowLocal.minute + 45) % 1440,
      );

      await service.reconcile();

      final MissionNotificationMirrorEntry entry = platform.mirror.singleWhere(
        (e) => e.kind == MissionNotificationKind.dailySummary,
      );
      expect(
        entry.systemNotificationId,
        NotificationReconciliationService.dailySummarySystemNotificationId,
      );
      // El espejo no tiene campo de texto: tras un reinicio el resumen sale
      // invitando a abrir la aplicación, sin dar cifras.
      expect(entry.showDetails, isFalse);
    });

    test('desactivarlo lo cancela y lo saca del espejo', () async {
      await reminderPreferencesRepository.save(
        ReminderPreferences.defaults.copyWith(
          leadMinutes: 0,
          dailySummaryEnabled: false,
        ),
      );

      final report = await service.reconcile();

      expect(report.dailySummaryScheduled, isFalse);
      expect(
        platform.cancelled,
        contains(
          NotificationReconciliationService.dailySummarySystemNotificationId,
        ),
      );
      expect(platform.mirror, isEmpty);
    });

    test('el texto se adapta a cero, una y varias misiones', () {
      expect(
        NotificationReconciliationService.dailySummaryText(0),
        'Hoy no tienes misiones programadas.',
      );
      expect(
        NotificationReconciliationService.dailySummaryText(1),
        'Hoy tienes 1 misión.',
      );
      expect(
        NotificationReconciliationService.dailySummaryText(8),
        'Hoy tienes 8 misiones.',
      );
    });

    test('añade los deseos a tu alcance, solo como número', () {
      expect(
        NotificationReconciliationService.dailySummaryText(
          3,
          affordableWishes: 0,
        ),
        'Hoy tienes 3 misiones.',
      );
      expect(
        NotificationReconciliationService.dailySummaryText(
          0,
          affordableWishes: 1,
        ),
        'Hoy no tienes misiones programadas. 1 deseo a tu alcance.',
      );
      expect(
        NotificationReconciliationService.dailySummaryText(
          1,
          affordableWishes: 2,
        ),
        'Hoy tienes 1 misión. 2 deseos a tu alcance.',
      );
    });

    test('el resumen programado incluye los deseos a tu alcance', () async {
      await enableSummary(minutes: 6 * 60);
      final NotificationReconciliationService withWishes =
          NotificationReconciliationService(
            notificationDao: notificationDao,
            settingsDao: settingsDao,
            reminderPreferencesRepository: reminderPreferencesRepository,
            platform: platform,
            nowUtc: () =>
                DateTime.fromMillisecondsSinceEpoch(_nowMs, isUtc: true),
            affordableWishCount: () async => 2,
          );

      await withWishes.reconcile();

      final MissionNotificationRequest summary = platform.scheduledRequests
          .singleWhere((r) => r.kind == MissionNotificationKind.dailySummary);
      expect(summary.contentText, endsWith(' 2 deseos a tu alcance.'));
    });

    test('si contar deseos falla, el resumen de misiones sigue', () async {
      await enableSummary(minutes: 6 * 60);
      final NotificationReconciliationService failing =
          NotificationReconciliationService(
            notificationDao: notificationDao,
            settingsDao: settingsDao,
            reminderPreferencesRepository: reminderPreferencesRepository,
            platform: platform,
            nowUtc: () =>
                DateTime.fromMillisecondsSinceEpoch(_nowMs, isUtc: true),
            affordableWishCount: () async => throw StateError('sin base'),
          );

      final report = await failing.reconcile();

      expect(report.dailySummaryScheduled, isTrue);
      final MissionNotificationRequest summary = platform.scheduledRequests
          .singleWhere((r) => r.kind == MissionNotificationKind.dailySummary);
      expect(summary.contentText, isNot(contains('deseo')));
    });
  });
  group('texto del aviso', () {
    test(
      'sin detalles usa el texto configurable, no el fijo de Kotlin',
      () async {
        await reminderPreferencesRepository.save(
          ReminderPreferences.defaults.copyWith(
            leadMinutes: 0,
            genericText: 'Toca ponerse.',
          ),
        );
        await _insertSchedule(
          database,
          missionId: 'custom-text',
          scheduleId: 'custom-text-schedule',
          notifyAt: _nowMs + 60000,
        );

        await service.reconcile();

        final MissionNotificationRequest request = platform.scheduledRequests
            .singleWhere((r) => r.kind == MissionNotificationKind.mission);
        expect(request.contentText, 'Toca ponerse.');
        expect(
          request.showDetails,
          isFalse,
          reason: 'sin detalles no debe viajar el título',
        );
      },
    );

    test('con detalles el texto es el título de la misión', () async {
      await settingsDao.putMetadata(
        key: AppPreferences.showNotificationDetailsMetadataKey,
        value: '1',
        updatedAtUtcMs: _nowMs,
      );
      await reminderPreferencesRepository.save(
        ReminderPreferences.defaults.copyWith(
          leadMinutes: 0,
          genericText: 'Toca ponerse.',
        ),
      );
      await _insertSchedule(
        database,
        missionId: 'titled',
        scheduleId: 'titled-schedule',
        notifyAt: _nowMs + 60000,
      );

      await service.reconcile();

      final MissionNotificationRequest request = platform.scheduledRequests
          .singleWhere((r) => r.kind == MissionNotificationKind.mission);
      expect(request.contentText, 'Misión privada');
    });

    test('un texto vacío no se guarda y conserva el anterior', () async {
      final result = await reminderPreferencesRepository.save(
        ReminderPreferences.defaults.copyWith(genericText: '   '),
      );

      expect(result, isA<Failure<void>>());
    });
  });
}

Future<void> _insertSchedule(
  AppDatabase database, {
  required String missionId,
  required String scheduleId,
  required int notifyAt,
  String status = 'PENDING',
  int? systemNotificationId,
}) async {
  await database
      .into(database.missions)
      .insert(
        MissionsCompanion.insert(
          id: missionId,
          areaId: DefaultSeedV1.studiesAreaId,
          title: 'Misión privada',
          missionType: 'PRIMARY',
          isRequired: 0,
          status: 'SCHEDULED',
          scheduledAt: Value<int?>(notifyAt),
          xpPlanned: 10,
        ),
      );
  await database
      .into(database.notificationSchedules)
      .insert(
        NotificationSchedulesCompanion.insert(
          id: scheduleId,
          missionId: missionId,
          notificationType: 'START',
          notifyAt: notifyAt,
          status: status,
          systemNotificationId: Value<int?>(systemNotificationId),
          createdAt: _nowMs,
          updatedAt: _nowMs,
        ),
      );
}

final class _FakeNotificationPlatform implements MissionNotificationPlatform {
  bool permissionGranted = true;
  int permissionRequests = 0;
  final List<String> scheduled = <String>[];
  final List<MissionNotificationRequest> scheduledRequests =
      <MissionNotificationRequest>[];
  final List<String> delivered = <String>[];
  final List<int> cancelled = <int>[];
  final List<MissionNotificationMirrorEntry> mirror =
      <MissionNotificationMirrorEntry>[];
  int mirrorSyncs = 0;
  bool mirrorSyncFails = false;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<int> schedule(MissionNotificationRequest request) async {
    scheduled.add(request.scheduleId);
    scheduledRequests.add(request);
    return request.systemNotificationId ?? 1001;
  }

  @override
  Future<int> deliverIfNeeded(MissionNotificationRequest request) async {
    delivered.add(request.scheduleId);
    return request.systemNotificationId ?? 1002;
  }

  @override
  Future<void> syncBootMirror(
    List<MissionNotificationMirrorEntry> entries,
  ) async {
    mirrorSyncs++;
    if (mirrorSyncFails) {
      throw StateError('mirror unavailable');
    }
    mirror
      ..clear()
      ..addAll(entries);
  }

  @override
  Future<void> cancel(int systemNotificationId) async {
    cancelled.add(systemNotificationId);
  }
}
