import 'dart:convert';

import 'package:bitacora_rpg_personal/app/application/commands/complete_mission.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/models/mission.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart'
    hide Mission;
import 'package:bitacora_rpg_personal/infrastructure/database/default_seed_v1.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/units_of_work/drift_complete_mission_unit_of_work.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late Mission mission;
  late CompleteMissionCommand command;
  final DateTime completedAt = DateTime.utc(2026, 8, 26, 18);

  setUp(() async {
    database = AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => completedAt.millisecondsSinceEpoch,
    );
    mission = const Mission(
      id: 'mission-partial-xp',
      areaId: DefaultSeedV1.studiesAreaId,
      title: 'Misión con avance parcial',
      type: MissionType.custom,
      importance: MissionImportance.important,
      priority: MissionPriority.normal,
      isRequired: false,
      status: MissionStatus.available,
      xpPlanned: 50,
      rowVersion: 1,
    );
    await database
        .into(database.missions)
        .insert(
          MissionsCompanion.insert(
            id: mission.id,
            areaId: mission.areaId,
            title: mission.title,
            missionType: 'CUSTOM',
            importance: const Value<String>('IMPORTANT'),
            isRequired: 0,
            status: 'AVAILABLE',
            xpPlanned: mission.xpPlanned,
          ),
        );
    var next = 0;
    command = CompleteMissionCommand(
      unitOfWork: DriftCompleteMissionUnitOfWork(database),
      nowUtc: () => completedAt,
      nextId: () => 'partial-operation-${next++}',
    );
  });

  tearDown(() => database.close());

  test('persiste el XP parcial elegido en ledger, evento y recibo', () async {
    final Result<MissionCompletionReceipt> result = await command(
      _request(mission, xpAwarded: 17),
    );

    expect(result, isA<Success<MissionCompletionReceipt>>());
    final MissionCompletionReceipt receipt =
        (result as Success<MissionCompletionReceipt>).value;
    expect(receipt.xpAwarded, 17);
    expect(receipt.mission.status, MissionStatus.partial);

    final xp = await database.select(database.xpTransactions).getSingle();
    expect(xp.amount, 17);
    expect(xp.reason, 'Misión completada parcialmente');

    final event = await database.select(database.missionEvents).getSingle();
    final Map<String, Object?> snapshot =
        jsonDecode(event.snapshotJson!) as Map<String, Object?>;
    expect(snapshot['xp_awarded'], 17);
  });

  test('rechaza XP parcial mayor al plan antes de escribir', () async {
    final Result<MissionCompletionReceipt> result = await command(
      _request(mission, xpAwarded: 51),
    );

    expect(result, isA<Failure<MissionCompletionReceipt>>());
    expect(await database.select(database.xpTransactions).get(), isEmpty);
    expect(
      (await database.select(database.missions).getSingle()).status,
      'AVAILABLE',
    );
  });

  test('permite finalizar sin describir un resultado', () async {
    final Result<MissionCompletionReceipt> result = await command(
      _request(mission, xpAwarded: 0, actualResult: '   '),
    );

    expect(result, isA<Success<MissionCompletionReceipt>>());
    expect(
      (await database.select(database.missions).getSingle()).actualResult,
      null,
    );
    expect(
      (await database.select(database.journalEntries).getSingle()).body,
      null,
    );
  });
}

CompleteMissionRequest _request(
  Mission mission, {
  required int xpAwarded,
  String? actualResult = 'Se completó una parte verificable del trabajo.',
}) => CompleteMissionRequest(
  mission: mission,
  outcome: MissionCompletionOutcome.partial,
  actualResult: actualResult,
  completedObjectiveIds: const <String>{},
  xpAwarded: xpAwarded,
);
