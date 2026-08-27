import 'package:bitacora_rpg_personal/features/notifications/application/notification_reconciliation_service.dart';
import 'package:bitacora_rpg_personal/features/notifications/domain/mission_notification_platform.dart';
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
  late _FakeNotificationPlatform platform;
  late NotificationReconciliationService service;

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => _nowMs,
    );
    notificationDao = NotificationDao(database);
    settingsDao = SettingsDao(database);
    platform = _FakeNotificationPlatform();
    service = NotificationReconciliationService(
      notificationDao: notificationDao,
      settingsDao: settingsDao,
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
  final List<String> delivered = <String>[];
  final List<int> cancelled = <int>[];

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<int> schedule(MissionNotificationRequest request) async {
    scheduled.add(request.scheduleId);
    return request.systemNotificationId ?? 1001;
  }

  @override
  Future<int> deliverIfNeeded(MissionNotificationRequest request) async {
    delivered.add(request.scheduleId);
    return request.systemNotificationId ?? 1002;
  }

  @override
  Future<void> cancel(int systemNotificationId) async {
    cancelled.add(systemNotificationId);
  }
}
