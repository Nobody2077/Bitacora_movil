import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/journal/data/drift_daily_close_repository.dart';
import 'package:bitacora_rpg_personal/features/missions/data/drift_mission_repository.dart';
import 'package:bitacora_rpg_personal/features/progress/application/progress_application_service.dart';
import 'package:bitacora_rpg_personal/features/progress/data/drift_progress_repository.dart';
import 'package:bitacora_rpg_personal/features/progress/domain/models/progress_models.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart'
    as drift;
import 'package:bitacora_rpg_personal/infrastructure/database/daos/daily_close_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/mission_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/progress_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/default_seed_v1.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime nowUtc = DateTime.utc(2026, 8, 27, 18);
  final DateTime localDay = DateTime(2026, 8, 27);
  late drift.AppDatabase database;
  late DriftProgressRepository progressRepository;
  late DriftDailyCloseRepository dailyCloseRepository;
  late DriftMissionRepository missionRepository;
  late ProgressApplicationService service;

  setUp(() {
    database = drift.AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => nowUtc.millisecondsSinceEpoch,
    );
    progressRepository = DriftProgressRepository(ProgressDao(database));
    dailyCloseRepository = DriftDailyCloseRepository(DailyCloseDao(database));
    missionRepository = DriftMissionRepository(MissionDao(database));
    service = ProgressApplicationService(
      progressRepository: progressRepository,
      dailyCloseRepository: dailyCloseRepository,
      missionRepository: missionRepository,
      clock: _FixedProgressClock(nowUtc),
    );
  });

  tearDown(() => database.close());

  test('calcula DailyDashboardData con nivel RPG y métricas del día', () async {
    await _insertXpTransaction(
      database,
      nowUtc,
      amount: 4450,
      areaId: DefaultSeedV1.personalAreaId,
    );

    final Result<DailyDashboardViewData> result = await service
        .loadDailyDashboard(localDay);

    expect(result, isA<Success<DailyDashboardViewData>>());
    final DailyDashboardViewData data =
        (result as Success<DailyDashboardViewData>).value;
    expect(data.rpgLevel.level, 7);
    expect(data.rpgLevel.effectiveXp, 4450);
    expect(data.rpgLevel.xpToNextLevel, 450);
    expect(data.todayXp, 4450);
    expect(data.totalXp, 4450);
  });

  test(
    'calcula WeeklyDashboardData con distribución por áreas y totales',
    () async {
      await _insertXpTransaction(
        database,
        nowUtc,
        amount: 1000,
        areaId: DefaultSeedV1.personalAreaId,
      );
      await _insertXpTransaction(
        database,
        nowUtc,
        amount: 500,
        areaId: DefaultSeedV1.healthAreaId,
      );

      final Result<WeeklyDashboardViewData> result = await service
          .loadWeeklyDashboard(localDay);

      expect(result, isA<Success<WeeklyDashboardViewData>>());
      final WeeklyDashboardViewData data =
          (result as Success<WeeklyDashboardViewData>).value;
      expect(data.weekXp, 1500);
      expect(data.totalXp, 1500);
      expect(data.areaBreakdown, hasLength(2));
      expect(data.areaBreakdown.first.areaName, 'Personal');
      expect(data.areaBreakdown.first.amount, 1000);
      expect(data.areaBreakdown.first.percentage, closeTo(66.6, 0.1));
    },
  );

  test(
    'calcula OverallProgressData con nivel global y desglose histórico',
    () async {
      await _insertXpTransaction(
        database,
        nowUtc,
        amount: 2450,
        areaId: DefaultSeedV1.projectsAreaId,
      );

      final Result<OverallProgressViewData> result = await service
          .loadOverallProgress();

      expect(result, isA<Success<OverallProgressViewData>>());
      final OverallProgressViewData data =
          (result as Success<OverallProgressViewData>).value;
      expect(data.rpgLevel.level, 5);
      expect(data.totalXp, 2450);
      expect(data.areaBreakdown, hasLength(1));
      expect(data.areaBreakdown.first.areaName, 'Proyectos');
      expect(data.areaBreakdown.first.percentage, 100.0);
    },
  );
}

Future<void> _insertXpTransaction(
  drift.AppDatabase database,
  DateTime timeUtc, {
  required int amount,
  required String areaId,
}) async {
  await database.customStatement(
    '''
      INSERT INTO xp_transactions (
        id, area_id, source_type, amount, occurred_at
      ) VALUES (?, ?, 'MISSION', ?, ?)
    ''',
    <Object?>[
      'xp-item-${DateTime.now().microsecondsSinceEpoch}-$amount',
      areaId,
      amount,
      timeUtc.millisecondsSinceEpoch,
    ],
  );
}

final class _FixedProgressClock implements ProgressClock {
  const _FixedProgressClock(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}
