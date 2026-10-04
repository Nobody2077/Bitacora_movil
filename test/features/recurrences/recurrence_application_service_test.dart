import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/missions/application/mission_application_service.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/models/mission.dart';
import 'package:bitacora_rpg_personal/features/recurrences/application/recurrence_application_service.dart';
import 'package:bitacora_rpg_personal/features/recurrences/application/recurrence_civil_time.dart';
import 'package:bitacora_rpg_personal/features/recurrences/data/drift_recurrence_repository.dart';
import 'package:bitacora_rpg_personal/features/recurrences/domain/models/recurrence_template.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/recurrence_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/default_seed_v1.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late RecurrenceDao dao;
  late DriftRecurrenceRepository repository;
  late _SequenceIds ids;
  late RecurrenceApplicationService service;

  final DateTime nowUtc = DateTime.utc(2026, 8, 26, 12);

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => nowUtc.millisecondsSinceEpoch,
    );
    dao = RecurrenceDao(database);
    repository = DriftRecurrenceRepository(dao);
    ids = _SequenceIds();
    service = RecurrenceApplicationService(
      repository: repository,
      dao: dao,
      clock: _FixedClock(nowUtc),
      idGenerator: ids,
      civilTime: const _UtcCivilTime(),
    );
  });

  tearDown(() => database.close());

  test(
    'genera exactamente 30 fechas diarias y no duplica al reintentar',
    () async {
      final Result<RecurrenceTemplate> saved = await service.saveTemplate(
        _request(
          frequency: RecurrenceFrequency.daily,
          startDate: '2026-08-26',
          objectives: const <RecurrenceObjectiveDraft>[
            RecurrenceObjectiveDraft(description: 'Objetivo uno'),
            RecurrenceObjectiveDraft(description: 'Objetivo dos'),
          ],
        ),
      );
      expect(saved, isA<Success<RecurrenceTemplate>>());

      final Result<int> first = await service.generatePendingOccurrences(
        localTodayOverride: '2026-08-26',
      );
      expect((first as Success<int>).value, 30);
      expect(await database.select(database.missions).get(), hasLength(30));
      expect(
        await database.select(database.missionObjectives).get(),
        hasLength(60),
      );
      expect(
        await database.select(database.missionEvents).get(),
        hasLength(30),
      );
      expect(
        await database.select(database.notificationSchedules).get(),
        isEmpty,
      );
      final occurrences = await database.select(database.missions).get();
      expect(
        occurrences.every((mission) => mission.availableFrom != null),
        isTrue,
      );
      expect(occurrences.every((mission) => mission.expiresAt != null), isTrue);

      final Result<int> retried = await service.generatePendingOccurrences(
        localTodayOverride: '2026-08-26',
      );
      expect((retried as Success<int>).value, 0);
      expect(await database.select(database.missions).get(), hasLength(30));
    },
  );

  test('cada N días conserva la fase anclada en startDate', () async {
    await service.saveTemplate(
      _request(
        frequency: RecurrenceFrequency.everyNDays,
        intervalValue: 2,
        startDate: '2026-08-25',
      ),
    );

    final Result<int> generated = await service.generatePendingOccurrences(
      localTodayOverride: '2026-08-26',
    );
    expect(generated, isA<Success<int>>());

    final missions = await (database.select(
      database.missions,
    )..orderBy([(table) => OrderingTerm.asc(table.scheduledAt)])).get();
    expect(missions, isNotEmpty);
    expect(
      DateTime.fromMillisecondsSinceEpoch(
        missions.first.scheduledAt!,
        isUtc: true,
      ).toIso8601String(),
      startsWith('2026-08-27T00:00:00'),
    );
    expect(
      missions.map((mission) => mission.scheduledAt).toSet(),
      hasLength(missions.length),
    );
  });

  test('una recurrencia con hora fija crea avisos de inicio', () async {
    await service.saveTemplate(
      _request(
        frequency: RecurrenceFrequency.daily,
        startDate: '2026-08-26',
        localTimeMinutes: 8 * 60 + 30,
      ),
    );

    await service.generatePendingOccurrences(localTodayOverride: '2026-08-26');

    final missions = await database.select(database.missions).get();
    final notifications = await database
        .select(database.notificationSchedules)
        .get();
    expect(missions, hasLength(30));
    expect(notifications, hasLength(30));
    expect(missions.every((mission) => mission.availableFrom == null), isTrue);
    expect(missions.every((mission) => mission.expiresAt == null), isTrue);
  });

  test('editar una plantilla pausada no la reactiva', () async {
    final created =
        (await service.saveTemplate(
                  _request(
                    frequency: RecurrenceFrequency.weekly,
                    startDate: '2026-08-26',
                  ),
                )
                as Success<RecurrenceTemplate>)
            .value;
    final paused =
        (await service.pauseTemplate(created.id) as Success<RecurrenceTemplate>)
            .value;

    final Result<RecurrenceTemplate> edited = await service.saveTemplate(
      _request(
        existing: paused,
        title: 'Plantilla editada',
        frequency: RecurrenceFrequency.weekly,
        startDate: '2026-08-26',
      ),
    );

    expect((edited as Success<RecurrenceTemplate>).value.isActive, isFalse);
  });

  test(
    'la edición de raíz, objetivos y regla revierte como una unidad',
    () async {
      final original =
          (await service.saveTemplate(
                    _request(
                      frequency: RecurrenceFrequency.daily,
                      startDate: '2026-08-26',
                    ),
                  )
                  as Success<RecurrenceTemplate>)
              .value;
      final RecurrenceTemplate invalid = original.copyWith(
        title: 'No debe persistir',
        objectives: const <RecurrenceObjective>[
          RecurrenceObjective(id: 'duplicate-a', description: 'A', position: 0),
          RecurrenceObjective(id: 'duplicate-b', description: 'B', position: 0),
        ],
      );

      expect(
        await repository.update(invalid),
        isA<Failure<RecurrenceTemplate>>(),
      );
      final stored =
          (await repository.findById(original.id)
                  as Success<RecurrenceTemplate?>)
              .value!;
      expect(stored.title, original.title);
      expect(stored.objectives, hasLength(original.objectives.length));
    },
  );

  test('el tablón no autogenera y tomar una misión es idempotente', () async {
    final saved =
        (await service.saveTemplate(
                  _request(
                    frequency: RecurrenceFrequency.daily,
                    startDate: '2026-08-26',
                    missionType: MissionType.daily,
                    availabilityMode: TemplateAvailabilityMode.board,
                    objectives: const <RecurrenceObjectiveDraft>[
                      RecurrenceObjectiveDraft(description: 'Paso del tablón'),
                    ],
                  ),
                )
                as Success<RecurrenceTemplate>)
            .value;

    final generated = await service.generatePendingOccurrences(
      localTodayOverride: '2026-08-26',
    );
    expect((generated as Success<int>).value, 0);
    expect(await database.select(database.missions).get(), isEmpty);

    final before = await service.watchMissionBoard().first;
    final beforeEntries = (before as Success<List<MissionBoardEntry>>).value;
    expect(beforeEntries, hasLength(1));
    expect(beforeEntries.single.isTakenToday, isFalse);

    final first = await service.takeMissionFromBoard(saved.id);
    final firstTake = (first as Success<MissionBoardTake>).value;
    expect(firstTake.created, isTrue);

    final retried = await service.takeMissionFromBoard(saved.id);
    final retryTake = (retried as Success<MissionBoardTake>).value;
    expect(retryTake.created, isFalse);
    expect(retryTake.missionId, firstTake.missionId);
    expect(await database.select(database.missions).get(), hasLength(1));
    expect(
      await database.select(database.missionObjectives).get(),
      hasLength(1),
    );

    final after = await service.watchMissionBoard().first;
    final afterEntry = (after as Success<List<MissionBoardEntry>>).value.single;
    expect(afterEntry.missionId, firstTake.missionId);
    expect(afterEntry.missionStatus, MissionStatus.available);
  });

  test('no mezcla modos cuando la plantilla ya generó misiones', () async {
    final automatic =
        (await service.saveTemplate(
                  _request(
                    frequency: RecurrenceFrequency.daily,
                    startDate: '2026-08-26',
                    missionType: MissionType.daily,
                  ),
                )
                as Success<RecurrenceTemplate>)
            .value;
    await service.generatePendingOccurrences(localTodayOverride: '2026-08-26');

    final changed = await service.saveTemplate(
      _request(
        existing: automatic,
        frequency: RecurrenceFrequency.daily,
        startDate: '2026-08-26',
        missionType: MissionType.daily,
        availabilityMode: TemplateAvailabilityMode.board,
      ),
    );

    expect(changed, isA<Failure<RecurrenceTemplate>>());
  });

  test('la plantilla guarda su ubicación y la copia a cada misión', () async {
    final RecurrenceTemplate automatic =
        (await service.saveTemplate(
                  _request(
                    frequency: RecurrenceFrequency.daily,
                    startDate: '2026-08-26',
                    location: '  Biblioteca central  ',
                  ),
                )
                as Success<RecurrenceTemplate>)
            .value;
    expect(automatic.location, 'Biblioteca central');

    await service.generatePendingOccurrences(localTodayOverride: '2026-08-26');
    final generated = await database.select(database.missions).get();
    expect(generated, isNotEmpty);
    expect(
      generated.every((row) => row.location == 'Biblioteca central'),
      isTrue,
    );

    final RecurrenceTemplate board =
        (await service.saveTemplate(
                  _request(
                    frequency: RecurrenceFrequency.daily,
                    startDate: '2026-08-26',
                    missionType: MissionType.daily,
                    availabilityMode: TemplateAvailabilityMode.board,
                    title: 'Del tablón',
                    location: 'Gimnasio',
                  ),
                )
                as Success<RecurrenceTemplate>)
            .value;
    final MissionBoardTake take =
        (await service.takeMissionFromBoard(board.id)
                as Success<MissionBoardTake>)
            .value;
    final taken = await (database.select(
      database.missions,
    )..where((table) => table.id.equals(take.missionId))).getSingle();
    expect(taken.location, 'Gimnasio');
  });

  test('rechaza una ubicación de más de 120 caracteres', () async {
    final Result<RecurrenceTemplate> saved = await service.saveTemplate(
      _request(
        frequency: RecurrenceFrequency.daily,
        startDate: '2026-08-26',
        location: 'x' * 121,
      ),
    );

    expect(saved, isA<Failure<RecurrenceTemplate>>());
    expect(await database.select(database.missionTemplates).get(), isEmpty);
  });
}

SaveTemplateRequest _request({
  required RecurrenceFrequency frequency,
  required String startDate,
  RecurrenceTemplate? existing,
  MissionType missionType = MissionType.recurring,
  TemplateAvailabilityMode availabilityMode =
      TemplateAvailabilityMode.automatic,
  String title = 'Rutina recurrente',
  String? location,
  int intervalValue = 1,
  int? localTimeMinutes,
  List<RecurrenceObjectiveDraft> objectives = const <RecurrenceObjectiveDraft>[
    RecurrenceObjectiveDraft(description: 'Objetivo base'),
  ],
}) => SaveTemplateRequest(
  existing: existing,
  location: location,
  areaId: DefaultSeedV1.studiesAreaId,
  title: title,
  missionType: missionType,
  availabilityMode: availabilityMode,
  importance: MissionImportance.normal,
  priority: MissionPriority.normal,
  isRequired: false,
  xpReward: 25,
  frequency: frequency,
  intervalValue: intervalValue,
  localTimeMinutes: localTimeMinutes,
  startDate: startDate,
  timezoneId: 'UTC',
  objectives: objectives,
);

final class _FixedClock implements MissionClock {
  const _FixedClock(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _SequenceIds implements MissionIdGenerator {
  int _next = 0;

  @override
  String nextId() => 'generated-${_next++}';
}

final class _UtcCivilTime implements RecurrenceCivilTime {
  const _UtcCivilTime();

  @override
  Future<String> currentTimeZoneId() async => 'UTC';

  @override
  Future<String> localDateForUtc({
    required int utcEpochMillis,
    required String timeZoneId,
  }) async => DateTime.fromMillisecondsSinceEpoch(
    utcEpochMillis,
    isUtc: true,
  ).toIso8601String().substring(0, 10);

  @override
  Future<int> localDateTimeToUtcEpochMillis({
    required String localDate,
    required int localTimeMinutes,
    required String timeZoneId,
  }) async {
    final DateTime date = DateTime.parse('${localDate}T00:00:00Z');
    return date.add(Duration(minutes: localTimeMinutes)).millisecondsSinceEpoch;
  }
}
