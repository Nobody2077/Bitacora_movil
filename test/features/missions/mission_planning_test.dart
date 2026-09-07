import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/missions/application/mission_application_service.dart';
import 'package:bitacora_rpg_personal/features/missions/data/drift_mission_repository.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/models/mission.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart'
    as drift;
import 'package:bitacora_rpg_personal/infrastructure/database/daos/mission_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/default_seed_v1.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late drift.AppDatabase database;
  late MissionApplicationService service;

  final DateTime nowUtc = DateTime.utc(2026, 8, 29, 12);

  setUp(() {
    database = drift.AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => nowUtc.millisecondsSinceEpoch,
    );
    service = MissionApplicationService(
      repository: DriftMissionRepository(MissionDao(database)),
      clock: _FixedClock(nowUtc),
      idGenerator: _SequenceIds(),
    );
  });

  tearDown(() => database.close());

  test('una misión sin fecha queda disponible y sin aviso', () async {
    final Mission mission = await _save(service, title: 'Sin planificar');

    expect(mission.isUnscheduled, isTrue);
    expect(mission.status, MissionStatus.available);
    expect(
      await database.select(database.notificationSchedules).get(),
      isEmpty,
    );
  });

  test('una misión de solo fecha conserva el día sin crear aviso', () async {
    final DateTime startUtc = DateTime.utc(2026, 8, 30);
    final Mission mission = await _save(
      service,
      title: 'Durante el día',
      scheduledAtUtc: startUtc,
      availableFromUtc: startUtc,
      expiresAtUtc: DateTime.utc(2026, 8, 30, 23, 59, 59, 999),
    );

    expect(mission.isDateOnly, isTrue);
    expect(mission.hasScheduledTime, isFalse);
    expect(mission.status, MissionStatus.scheduled);
    expect(
      await database.select(database.notificationSchedules).get(),
      isEmpty,
    );
  });

  test('una misión con fecha y hora crea un aviso de inicio', () async {
    final Mission mission = await _save(
      service,
      title: 'Con hora',
      scheduledAtUtc: DateTime.utc(2026, 8, 30, 14, 30),
    );

    expect(mission.hasScheduledTime, isTrue);
    final notifications = await database
        .select(database.notificationSchedules)
        .get();
    expect(notifications, hasLength(1));
    expect(
      notifications.single.notifyAt,
      mission.scheduledAtUtc!.millisecondsSinceEpoch,
    );
  });

  test('editar a sin fecha actualiza el estado y cancela el aviso', () async {
    final Mission scheduled = await _save(
      service,
      title: 'Antes programada',
      scheduledAtUtc: DateTime.utc(2026, 8, 30, 14, 30),
    );

    final Result<Mission> result = await service.save(
      SaveMissionRequest(
        existing: scheduled,
        areaId: scheduled.areaId,
        title: scheduled.title,
        type: scheduled.type,
        importance: scheduled.importance,
        priority: scheduled.priority,
        isRequired: scheduled.isRequired,
        xpPlanned: scheduled.xpPlanned,
        objectives: const <MissionObjectiveDraft>[],
      ),
    );

    final Mission updated = (result as Success<Mission>).value;
    expect(updated.isUnscheduled, isTrue);
    expect(updated.status, MissionStatus.available);
    final notifications = await database
        .select(database.notificationSchedules)
        .get();
    expect(notifications.single.status, 'CANCELLED');
  });
  test(
    'una misión con hora y vencimiento crea aviso de inicio y de vencimiento',
    () async {
      final DateTime startUtc = DateTime.utc(2026, 8, 30, 9);
      final DateTime expiresUtc = DateTime.utc(2026, 8, 30, 18);
      await _save(
        service,
        title: 'Entrega con plazo',
        scheduledAtUtc: startUtc,
        expiresAtUtc: expiresUtc,
      );

      final rows = await database.select(database.notificationSchedules).get();
      final Map<String, int> byType = <String, int>{
        for (final row in rows) row.notificationType: row.notifyAt,
      };
      expect(byType.keys, containsAll(<String>['START', 'CRITICAL']));
      expect(byType['START'], startUtc.millisecondsSinceEpoch);
      expect(byType['CRITICAL'], expiresUtc.millisecondsSinceEpoch);
    },
  );

  test(
    'una misión con hora y sin vencimiento solo crea el aviso de inicio',
    () async {
      await _save(
        service,
        title: 'Sin plazo',
        scheduledAtUtc: DateTime.utc(2026, 8, 30, 9),
      );

      final rows = await database.select(database.notificationSchedules).get();
      expect(rows.map((row) => row.notificationType), <String>['START']);
    },
  );

  test('un vencimiento ya pasado no genera aviso', () async {
    await _save(
      service,
      title: 'Plazo vencido',
      scheduledAtUtc: DateTime.utc(2026, 8, 29, 6),
      expiresAtUtc: DateTime.utc(2026, 8, 29, 7),
    );

    final rows = await database.select(database.notificationSchedules).get();
    expect(
      rows.map((row) => row.notificationType),
      isNot(contains('CRITICAL')),
      reason: 'avisar de un plazo que ya pasó solo sería ruido',
    );
  });

  test(
    'mover el vencimiento cancela el aviso anterior y crea el nuevo',
    () async {
      final Mission created = await _save(
        service,
        title: 'Plazo movible',
        scheduledAtUtc: DateTime.utc(2026, 8, 30, 9),
        expiresAtUtc: DateTime.utc(2026, 8, 30, 18),
      );
      await _save(
        service,
        title: 'Plazo movible',
        scheduledAtUtc: DateTime.utc(2026, 8, 30, 9),
        expiresAtUtc: DateTime.utc(2026, 8, 31, 18),
        existing: created,
      );

      final rows = await database.select(database.notificationSchedules).get();
      final critical = rows.where((row) => row.notificationType == 'CRITICAL');
      expect(
        critical.where((row) => row.status == 'PENDING').single.notifyAt,
        DateTime.utc(2026, 8, 31, 18).millisecondsSinceEpoch,
      );
      expect(
        critical.where((row) => row.status == 'CANCELLED').length,
        1,
        reason: 'el plazo antiguo no debe seguir vivo',
      );
      expect(
        rows
            .where((row) => row.notificationType == 'START')
            .where((row) => row.status == 'PENDING')
            .length,
        1,
        reason: 'mover solo el vencimiento no debe tocar el aviso de inicio',
      );
    },
  );
}

Future<Mission> _save(
  MissionApplicationService service, {
  required String title,
  DateTime? scheduledAtUtc,
  DateTime? availableFromUtc,
  DateTime? expiresAtUtc,
  Mission? existing,
}) async {
  final Result<Mission> result = await service.save(
    SaveMissionRequest(
      areaId: DefaultSeedV1.studiesAreaId,
      title: title,
      type: MissionType.custom,
      importance: MissionImportance.normal,
      priority: MissionPriority.normal,
      isRequired: false,
      scheduledAtUtc: scheduledAtUtc,
      availableFromUtc: availableFromUtc,
      expiresAtUtc: expiresAtUtc,
      existing: existing,
      xpPlanned: 10,
      objectives: const <MissionObjectiveDraft>[],
    ),
  );
  return (result as Success<Mission>).value;
}

final class _FixedClock implements MissionClock {
  const _FixedClock(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _SequenceIds implements MissionIdGenerator {
  int _next = 0;

  @override
  String nextId() => 'planning-${_next++}';
}
