import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/missions/application/mission_application_service.dart';
import 'package:bitacora_rpg_personal/features/missions/data/drift_mission_repository.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/models/mission.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart'
    as drift;
import 'package:bitacora_rpg_personal/infrastructure/database/daos/mission_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime nowUtc = DateTime.utc(2026, 8, 27, 15);
  late drift.AppDatabase database;
  late DriftMissionRepository repository;
  late MissionApplicationService service;

  setUp(() {
    database = drift.AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => nowUtc.millisecondsSinceEpoch,
    );
    repository = DriftMissionRepository(MissionDao(database));
    service = MissionApplicationService(
      repository: repository,
      clock: _FixedMissionClock(nowUtc),
      idGenerator: _SequenceMissionIds(),
    );
  });

  tearDown(() => database.close());

  test('archivar conserva historia y cancela el aviso pendiente', () async {
    final mission = await _createMission(repository, service, nowUtc);

    final result = await service.archiveMission(mission);

    expect(result, isA<Success<Mission>>());
    final archived = (result as Success<Mission>).value;
    expect(archived.archivedAtUtc, nowUtc);
    expect(archived.rowVersion, mission.rowVersion + 1);
    final events = await (database.select(
      database.missionEvents,
    )..where((table) => table.missionId.equals(mission.id))).get();
    expect(events.map((event) => event.eventType), contains('ARCHIVED'));
    final notifications = await (database.select(
      database.notificationSchedules,
    )..where((table) => table.missionId.equals(mission.id))).get();
    expect(notifications, hasLength(1));
    expect(notifications.single.status, 'CANCELLED');
    final visible = await repository.watchAll().first;
    expect((visible as Success<List<Mission>>).value, isEmpty);
  });

  test('una misión con cronómetro activo no puede archivarse', () async {
    final mission = await _createMission(repository, service, nowUtc);
    final started = await service.startTimer(mission);
    final active = (started as Success<Mission>).value;

    final result = await service.archiveMission(active);

    expect(result, isA<Failure<Mission>>());
    final stored = await database.select(database.missions).getSingle();
    expect(stored.archivedAt, isNull);
    expect(await database.select(database.missionEvents).get(), hasLength(2));
  });
}

Future<Mission> _createMission(
  DriftMissionRepository repository,
  MissionApplicationService service,
  DateTime nowUtc,
) async {
  final areas = await repository.findVisibleAreas();
  final area = (areas as Success<List<MissionArea>>).value.first;
  final result = await service.save(
    SaveMissionRequest(
      areaId: area.id,
      title: 'Misión de prueba para archivar',
      type: MissionType.custom,
      importance: MissionImportance.normal,
      priority: MissionPriority.normal,
      isRequired: false,
      scheduledAtUtc: nowUtc.add(const Duration(hours: 1)),
      xpPlanned: 10,
      objectives: const <MissionObjectiveDraft>[],
    ),
  );
  return (result as Success<Mission>).value;
}

final class _FixedMissionClock implements MissionClock {
  const _FixedMissionClock(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _SequenceMissionIds implements MissionIdGenerator {
  int _next = 0;

  @override
  String nextId() => 'archive-id-${_next++}';
}
