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
      expect(data.areaBreakdown.first.rpgLevel.level, 4);
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

  test(
    'activa, desactiva y recupera el título dinámico preservando la mejor racha',
    () async {
      for (int day = 21; day <= 27; day += 1) {
        await _insertCompletedMission(
          database,
          id: 'streak-a-$day',
          completedAt: DateTime(2026, 8, day, 12).toUtc(),
        );
      }

      final first = await service.loadOverallProgress();
      final firstData = (first as Success<OverallProgressViewData>).value;
      expect(firstData.currentStreak, 7);
      expect(firstData.bestStreak, 7);
      expect(firstData.activeTitles, hasLength(1));
      expect(firstData.activeTitles.single.name, 'Ritmo constante');
      expect(firstData.activeTitles.single.status, ProgressTitleStatus.active);
      expect(firstData.activeTitles.single.recoveryCount, 0);

      final DateTime brokenUtc = DateTime(2026, 8, 29, 18).toUtc();
      final brokenService = ProgressApplicationService(
        progressRepository: progressRepository,
        dailyCloseRepository: dailyCloseRepository,
        missionRepository: missionRepository,
        clock: _FixedProgressClock(brokenUtc),
      );
      final broken = await brokenService.loadOverallProgress();
      expect(
        (broken as Success<OverallProgressViewData>).value.activeTitles,
        isEmpty,
      );

      for (int day = 30; day <= 36; day += 1) {
        await _insertCompletedMission(
          database,
          id: 'streak-b-$day',
          completedAt: DateTime(2026, 8, day, 12).toUtc(),
        );
      }
      final DateTime recoveredUtc = DateTime(2026, 9, 5, 18).toUtc();
      final recoveredService = ProgressApplicationService(
        progressRepository: progressRepository,
        dailyCloseRepository: dailyCloseRepository,
        missionRepository: missionRepository,
        clock: _FixedProgressClock(recoveredUtc),
      );
      final recovered = await recoveredService.loadOverallProgress();
      final recoveredData =
          (recovered as Success<OverallProgressViewData>).value;
      expect(recoveredData.currentStreak, 7);
      expect(recoveredData.bestStreak, 7);
      expect(recoveredData.activeTitles, hasLength(1));
      expect(recoveredData.activeTitles.single.recoveryCount, 1);

      final history = await database.customSelect('''
        SELECT status, best_streak, recovery_count
        FROM title_history
        WHERE title_id = '${DefaultSeedV1.dailyStreakTitleId}'
        ORDER BY activated_at ASC
      ''').get();
      expect(history, hasLength(2));
      expect(history.first.read<String>('status'), 'INACTIVE');
      expect(history.first.read<int>('best_streak'), 7);
      expect(history.last.read<String>('status'), 'ACTIVE');
      expect(history.last.read<int>('recovery_count'), 1);
    },
  );

  test('gana permanentemente Centinela del hogar con 100 misiones', () async {
    await database.transaction(() async {
      for (int index = 0; index < 100; index += 1) {
        await _insertCompletedMission(
          database,
          id: 'home-$index',
          completedAt: DateTime(2026, 8, 27, 8).toUtc(),
          areaId: DefaultSeedV1.homeAreaId,
        );
      }
    });

    final result = await service.loadOverallProgress();
    final data = (result as Success<OverallProgressViewData>).value;
    final title = data.activeTitles.singleWhere(
      (item) => item.id == DefaultSeedV1.homeCentinelTitleId,
    );
    expect(title.status, ProgressTitleStatus.earned);

    final laterService = ProgressApplicationService(
      progressRepository: progressRepository,
      dailyCloseRepository: dailyCloseRepository,
      missionRepository: missionRepository,
      clock: _FixedProgressClock(DateTime.utc(2027, 1, 1)),
    );
    final later = await laterService.loadOverallProgress();
    expect(
      (later as Success<OverallProgressViewData>).value.activeTitles,
      contains(predicate<TitleProgressItem>((item) => item.id == title.id)),
    );
  });
}

Future<void> _insertCompletedMission(
  drift.AppDatabase database, {
  required String id,
  required DateTime completedAt,
  String areaId = DefaultSeedV1.personalAreaId,
}) async {
  await database.customStatement(
    '''
      INSERT INTO missions (
        id, area_id, title, mission_type, is_required, status,
        xp_planned, completed_at, row_version
      ) VALUES (?, ?, ?, 'DAILY', 0, 'COMPLETED', 0, ?, 1)
    ''',
    <Object?>[id, areaId, 'Misión $id', completedAt.millisecondsSinceEpoch],
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
