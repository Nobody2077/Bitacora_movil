import 'dart:async';

import 'package:bitacora_rpg_personal/app/providers/persistence_providers.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/models/daily_close.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/repositories/daily_close_repository.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/models/mission.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/repositories/mission_repository.dart';
import 'package:bitacora_rpg_personal/features/progress/domain/models/progress_models.dart';
import 'package:bitacora_rpg_personal/features/progress/domain/models/progress_snapshot.dart';
import 'package:bitacora_rpg_personal/features/progress/domain/repositories/progress_repository.dart';
import 'package:bitacora_rpg_personal/features/progress/presentation/dashboard_daily_page.dart';
import 'package:bitacora_rpg_personal/features/progress/presentation/dashboard_progress_page.dart';
import 'package:bitacora_rpg_personal/features/progress/presentation/dashboard_weekly_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeProgressRepository progressRepo;
  late _FakeDailyCloseRepository dailyCloseRepo;
  late _FakeMissionRepository missionRepo;

  setUp(() {
    progressRepo = _FakeProgressRepository(
      const ProgressSnapshot(
        totalXp: 4450,
        todayXp: 125,
        weekXp: 325,
        byArea: <AreaXp>[
          AreaXp(areaId: 'area-proj', amount: 2150),
          AreaXp(areaId: 'area-est', amount: 1200),
          AreaXp(areaId: 'area-sal', amount: 760),
        ],
      ),
      titles: <TitleProgressItem>[
        TitleProgressItem(
          id: 'title-streak',
          name: 'Ritmo constante',
          description: 'Siete días de misiones completadas.',
          kind: ProgressTitleKind.dynamic,
          status: ProgressTitleStatus.active,
          activatedAtUtc: DateTime.utc(2026, 8, 27),
          bestStreak: 7,
        ),
      ],
    );
    addTearDown(progressRepo.dispose);
    dailyCloseRepo = _FakeDailyCloseRepository(
      const DailyCloseSummary(
        completedMissions: <DailyCloseMission>[
          DailyCloseMission(id: 'm-1', title: 'Laboratorio de redes'),
        ],
        requiredPendingMissions: <DailyCloseMission>[],
        xpEarned: 125,
        workSeconds: 5400,
        incomeMinor: 15000,
        expenseMinor: 19200,
        mainAreaName: 'Proyectos',
      ),
    );
    missionRepo = _FakeMissionRepository(<MissionArea>[
      const MissionArea(
        id: 'area-proj',
        name: 'Proyectos',
        iconKey: 'code',
        colorHex: '#A855F7',
        isDefault: false,
      ),
      const MissionArea(
        id: 'area-est',
        name: 'Estudios',
        iconKey: 'school',
        colorHex: '#38BDF8',
        isDefault: false,
      ),
      const MissionArea(
        id: 'area-sal',
        name: 'Salud',
        iconKey: 'favorite',
        colorHex: '#22C55E',
        isDefault: false,
      ),
    ]);
  });

  testWidgets('DashboardDailyPage muestra nivel RPG y métricas del día', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider.overrideWithValue(progressRepo),
          dailyCloseRepositoryProvider.overrideWithValue(dailyCloseRepo),
          missionRepositoryProvider.overrideWithValue(missionRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: DashboardDailyPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PROGRESO Y DASHBOARDS'), findsOneWidget);
    expect(find.text('Nivel 7'), findsOneWidget);
    expect(find.text('850 / 1300 XP (65%)'), findsOneWidget);
    expect(find.text('+125 XP'), findsOneWidget);
    expect(find.text('1 h 30 min'), findsOneWidget);
  });

  testWidgets(
    'DashboardWeeklyPage muestra resumen consolidado y distribución por áreas',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 1400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            progressRepositoryProvider.overrideWithValue(progressRepo),
            dailyCloseRepositoryProvider.overrideWithValue(dailyCloseRepo),
            missionRepositoryProvider.overrideWithValue(missionRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(body: DashboardWeeklyPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PROGRESO Y DASHBOARDS'), findsOneWidget);
      expect(find.text('Nivel 7'), findsOneWidget);
      expect(find.text('Proyectos'), findsWidgets);
      expect(find.text('Estudios'), findsOneWidget);
      expect(find.text('Salud'), findsOneWidget);
    },
  );

  testWidgets('DashboardProgressPage muestra perfil global de aventura RPG', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider.overrideWithValue(progressRepo),
          dailyCloseRepositoryProvider.overrideWithValue(dailyCloseRepo),
          missionRepositoryProvider.overrideWithValue(missionRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: DashboardProgressPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PROGRESO Y DASHBOARDS'), findsOneWidget);
    expect(find.text('4450 XP'), findsOneWidget);
    expect(find.text('850 / 1300'), findsOneWidget);
    expect(find.text('Proyectos'), findsWidgets);
    expect(find.text('Ritmo constante'), findsOneWidget);
    expect(find.textContaining('Nivel 5 · 2150 XP'), findsOneWidget);
  });

  testWidgets('DashboardProgressPage reacciona a cambios persistidos', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider.overrideWithValue(progressRepo),
          dailyCloseRepositoryProvider.overrideWithValue(dailyCloseRepo),
          missionRepositoryProvider.overrideWithValue(missionRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: DashboardProgressPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('4450 XP'), findsOneWidget);

    progressRepo.snapshot = const ProgressSnapshot(
      totalXp: 5000,
      todayXp: 675,
      weekXp: 875,
      byArea: <AreaXp>[AreaXp(areaId: 'area-proj', amount: 5000)],
    );
    progressRepo.notifyChanged();
    await tester.pumpAndSettle();

    expect(find.text('5000 XP'), findsOneWidget);
    expect(find.text('+675 XP'), findsOneWidget);
  });
}

final class _FakeProgressRepository implements ProgressRepository {
  _FakeProgressRepository(
    this.snapshot, {
    this.titles = const <TitleProgressItem>[],
  });

  ProgressSnapshot snapshot;
  final List<TitleProgressItem> titles;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  void notifyChanged() => _changes.add(null);

  void dispose() => _changes.close();

  @override
  Future<Result<ProgressSnapshot>> loadSnapshot({
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    required DateTime weekStartUtc,
  }) async => Success<ProgressSnapshot>(snapshot);

  @override
  Future<Result<ProgressTitleRuleFacts>> loadTitleRuleFacts() async =>
      const Success<ProgressTitleRuleFacts>(
        ProgressTitleRuleFacts(
          definitions: <ProgressTitleDefinition>[],
          completedHomeMissions: 0,
          completionInstantsUtc: <DateTime>[],
        ),
      );

  @override
  Future<Result<List<TitleProgressItem>>> synchronizeTitles({
    required List<ProgressTitleDecision> decisions,
    required DateTime evaluatedAtUtc,
  }) async => Success<List<TitleProgressItem>>(titles);

  @override
  Stream<void> watchChanges() => _changes.stream;
}

final class _FakeDailyCloseRepository implements DailyCloseRepository {
  _FakeDailyCloseRepository(this.summary);

  final DailyCloseSummary summary;

  @override
  Future<Result<DailyCloseSummary>> loadSummary({
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    required DateTime referenceUtc,
  }) async => Success<DailyCloseSummary>(summary);
}

final class _FakeMissionRepository implements MissionRepository {
  _FakeMissionRepository(this.areas);

  final List<MissionArea> areas;

  @override
  Future<Result<List<MissionArea>>> findVisibleAreas() async =>
      Success<List<MissionArea>>(areas);

  @override
  Future<Result<Mission>> archive({
    required Mission mission,
    required String eventId,
    required DateTime occurredAtUtc,
  }) => throw UnimplementedError();

  @override
  Future<Result<Mission>> create(
    Mission mission, {
    required String eventId,
    required String notificationId,
    required String expiryNotificationId,
    required DateTime occurredAtUtc,
    Iterable<String> contactIds = const <String>[],
  }) => throw UnimplementedError();

  @override
  Future<Result<Mission?>> findActiveTimer() => throw UnimplementedError();

  @override
  Future<Result<Mission?>> findById(String id) => throw UnimplementedError();

  @override
  Future<Result<List<Mission>>> findScheduledBetween({
    required DateTime startUtc,
    required DateTime endUtc,
  }) => throw UnimplementedError();

  @override
  Future<Result<Mission>> pauseTimer({
    required String missionId,
    required int expectedRowVersion,
    required String eventId,
    required DateTime occurredAtUtc,
  }) => throw UnimplementedError();

  @override
  Future<Result<Mission>> startTimer({
    required String missionId,
    required int expectedRowVersion,
    required MissionStatus expectedStatus,
    required String timeEntryId,
    required String eventId,
    required DateTime occurredAtUtc,
  }) => throw UnimplementedError();

  @override
  Future<Result<Mission>> switchTimer({
    required Mission activeMission,
    required Mission targetMission,
    required String pauseEventId,
    required String timeEntryId,
    required String startEventId,
    required DateTime occurredAtUtc,
  }) => throw UnimplementedError();

  @override
  Future<Result<Mission>> update(
    Mission mission, {
    required String eventId,
    required String notificationId,
    required String expiryNotificationId,
    required DateTime occurredAtUtc,
    Iterable<String>? contactIds,
  }) => throw UnimplementedError();

  @override
  Stream<Result<List<Mission>>> watchAll() => throw UnimplementedError();

  @override
  Stream<Result<List<Mission>>> watchScheduledBetween({
    required DateTime startUtc,
    required DateTime endUtc,
  }) => throw UnimplementedError();

  @override
  Stream<Result<List<Mission>>> watchUpcoming({required DateTime startUtc}) =>
      throw UnimplementedError();
}
