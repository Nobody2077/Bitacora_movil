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
    expect(platform.cancelled, <int>[77]);

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
      expect(platform.cancelled, <int>[81]);
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
