import '../../../core/result/result.dart';
import '../../journal/domain/models/daily_close.dart';
import '../../journal/domain/repositories/daily_close_repository.dart';
import '../../missions/domain/models/mission.dart';
import '../../missions/domain/repositories/mission_repository.dart';
import '../domain/models/progress_models.dart';
import '../domain/models/progress_snapshot.dart';
import '../domain/models/rpg_level.dart';
import '../domain/repositories/progress_repository.dart';

abstract interface class ProgressClock {
  DateTime nowUtc();
}

final class SystemProgressClock implements ProgressClock {
  const SystemProgressClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

final class ProgressApplicationService {
  const ProgressApplicationService({
    required ProgressRepository progressRepository,
    required DailyCloseRepository dailyCloseRepository,
    required MissionRepository missionRepository,
    this.clock = const SystemProgressClock(),
  }) : _progressRepository = progressRepository,
       _dailyCloseRepository = dailyCloseRepository,
       _missionRepository = missionRepository;

  final ProgressRepository _progressRepository;
  final DailyCloseRepository _dailyCloseRepository;
  final MissionRepository _missionRepository;
  final ProgressClock clock;

  Future<Result<DailyDashboardViewData>> loadDailyDashboard(
    DateTime localDay,
  ) async {
    final DateTime dayStartUtc = DateTime(
      localDay.year,
      localDay.month,
      localDay.day,
    ).toUtc();
    final DateTime dayEndUtc = DateTime(
      localDay.year,
      localDay.month,
      localDay.day + 1,
    ).toUtc();
    final DateTime weekStartUtc = _weekStart(localDay).toUtc();
    final DateTime nowUtc = clock.nowUtc();

    final snapshotResult = await _progressRepository.loadSnapshot(
      dayStartUtc: dayStartUtc,
      dayEndUtc: dayEndUtc,
      weekStartUtc: weekStartUtc,
    );
    if (snapshotResult is Failure<ProgressSnapshot>) {
      return Failure<DailyDashboardViewData>(snapshotResult.failure);
    }
    final ProgressSnapshot snapshot =
        (snapshotResult as Success<ProgressSnapshot>).value;

    final summaryResult = await _dailyCloseRepository.loadSummary(
      dayStartUtc: dayStartUtc,
      dayEndUtc: dayEndUtc,
      referenceUtc: nowUtc,
    );
    if (summaryResult is Failure<DailyCloseSummary>) {
      return Failure<DailyDashboardViewData>(summaryResult.failure);
    }
    final DailyCloseSummary summary =
        (summaryResult as Success<DailyCloseSummary>).value;

    return Success<DailyDashboardViewData>(
      DailyDashboardViewData(
        localDay: localDay,
        rpgLevel: RpgLevel.fromTotalXp(snapshot.totalXp),
        todayXp: snapshot.todayXp,
        totalXp: snapshot.totalXp,
        dailyCloseSummary: summary,
      ),
    );
  }

  Future<Result<WeeklyDashboardViewData>> loadWeeklyDashboard(
    DateTime localDay,
  ) async {
    final DateTime weekStart = _weekStart(localDay);
    final DateTime weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 7,
    );
    final DateTime weekStartUtc = weekStart.toUtc();
    final DateTime weekEndUtc = weekEnd.toUtc();
    final DateTime nowUtc = clock.nowUtc();

    final snapshotResult = await _progressRepository.loadSnapshot(
      dayStartUtc: weekStartUtc,
      dayEndUtc: weekEndUtc,
      weekStartUtc: weekStartUtc,
    );
    if (snapshotResult is Failure<ProgressSnapshot>) {
      return Failure<WeeklyDashboardViewData>(snapshotResult.failure);
    }
    final ProgressSnapshot snapshot =
        (snapshotResult as Success<ProgressSnapshot>).value;

    final summaryResult = await _dailyCloseRepository.loadSummary(
      dayStartUtc: weekStartUtc,
      dayEndUtc: weekEndUtc,
      referenceUtc: nowUtc,
    );
    if (summaryResult is Failure<DailyCloseSummary>) {
      return Failure<WeeklyDashboardViewData>(summaryResult.failure);
    }
    final DailyCloseSummary summary =
        (summaryResult as Success<DailyCloseSummary>).value;

    final areasResult = await _missionRepository.findVisibleAreas();
    final List<MissionArea> areas = areasResult.fold(
      onSuccess: (items) => items,
      onFailure: (_) => const <MissionArea>[],
    );

    final List<AreaProgressItem> breakdown = _buildAreaBreakdown(
      byArea: snapshot.byArea,
      areas: areas,
      totalXp: snapshot.totalXp,
    );
    final titleSummaryResult = await _loadTitleSummary(
      nowUtc: nowUtc,
      localDay: nowUtc.toLocal(),
    );
    if (titleSummaryResult is Failure<_TitleSummary>) {
      return Failure<WeeklyDashboardViewData>(titleSummaryResult.failure);
    }
    final _TitleSummary titleSummary =
        (titleSummaryResult as Success<_TitleSummary>).value;

    return Success<WeeklyDashboardViewData>(
      WeeklyDashboardViewData(
        weekStart: weekStart,
        weekEnd: weekEnd.subtract(const Duration(days: 1)),
        rpgLevel: RpgLevel.fromTotalXp(snapshot.totalXp),
        weekXp: snapshot.weekXp,
        totalXp: snapshot.totalXp,
        areaBreakdown: breakdown,
        completedMissionsCount: summary.completedMissions.length,
        totalWorkSeconds: summary.workSeconds,
        weekIncomeMinor: summary.incomeMinor,
        weekExpenseMinor: summary.expenseMinor,
        currentStreak: titleSummary.currentStreak,
        bestStreak: titleSummary.bestStreak,
      ),
    );
  }

  Future<Result<OverallProgressViewData>> loadOverallProgress() async {
    final DateTime nowUtc = clock.nowUtc();
    final DateTime localNow = nowUtc.toLocal();
    final DateTime dayStartUtc = DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
    ).toUtc();
    final DateTime dayEndUtc = DateTime(
      localNow.year,
      localNow.month,
      localNow.day + 1,
    ).toUtc();
    final DateTime weekStartUtc = _weekStart(localNow).toUtc();

    final snapshotResult = await _progressRepository.loadSnapshot(
      dayStartUtc: dayStartUtc,
      dayEndUtc: dayEndUtc,
      weekStartUtc: weekStartUtc,
    );
    if (snapshotResult is Failure<ProgressSnapshot>) {
      return Failure<OverallProgressViewData>(snapshotResult.failure);
    }
    final ProgressSnapshot snapshot =
        (snapshotResult as Success<ProgressSnapshot>).value;

    final areasResult = await _missionRepository.findVisibleAreas();
    final List<MissionArea> areas = areasResult.fold(
      onSuccess: (items) => items,
      onFailure: (_) => const <MissionArea>[],
    );

    final List<AreaProgressItem> breakdown = _buildAreaBreakdown(
      byArea: snapshot.byArea,
      areas: areas,
      totalXp: snapshot.totalXp,
    );
    final titleSummaryResult = await _loadTitleSummary(
      nowUtc: nowUtc,
      localDay: localNow,
    );
    if (titleSummaryResult is Failure<_TitleSummary>) {
      return Failure<OverallProgressViewData>(titleSummaryResult.failure);
    }
    final _TitleSummary titleSummary =
        (titleSummaryResult as Success<_TitleSummary>).value;

    return Success<OverallProgressViewData>(
      OverallProgressViewData(
        rpgLevel: RpgLevel.fromTotalXp(snapshot.totalXp),
        totalXp: snapshot.totalXp,
        todayXp: snapshot.todayXp,
        weekXp: snapshot.weekXp,
        areaBreakdown: breakdown,
        activeTitles: titleSummary.activeTitles,
        currentStreak: titleSummary.currentStreak,
        bestStreak: titleSummary.bestStreak,
      ),
    );
  }

  DateTime _weekStart(DateTime day) {
    final int weekday = day.weekday; // 1 = Monday, 7 = Sunday
    final DateTime monday = day.subtract(Duration(days: weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  List<AreaProgressItem> _buildAreaBreakdown({
    required List<AreaXp> byArea,
    required List<MissionArea> areas,
    required int totalXp,
  }) {
    final Map<String, MissionArea> areaMap = <String, MissionArea>{
      for (final area in areas) area.id: area,
    };

    final List<AreaProgressItem> items = <AreaProgressItem>[];
    for (final areaXp in byArea) {
      final MissionArea? area = areaMap[areaXp.areaId];
      final String name = area?.name ?? 'Área desconocida';
      final String colorHex = area?.colorHex ?? '#55E6E6';
      final String iconKey = area?.iconKey ?? 'category';
      final double pct = totalXp > 0
          ? ((areaXp.amount / totalXp) * 100.0).clamp(0.0, 100.0)
          : 0.0;

      items.add(
        AreaProgressItem(
          areaId: areaXp.areaId,
          areaName: name,
          colorHex: colorHex,
          iconKey: iconKey,
          amount: areaXp.amount,
          percentage: pct,
          rpgLevel: RpgLevel.fromTotalXp(areaXp.amount),
        ),
      );
    }
    return items;
  }

  Future<Result<_TitleSummary>> _loadTitleSummary({
    required DateTime nowUtc,
    required DateTime localDay,
  }) async {
    final factsResult = await _progressRepository.loadTitleRuleFacts();
    if (factsResult is Failure<ProgressTitleRuleFacts>) {
      return Failure<_TitleSummary>(factsResult.failure);
    }
    final ProgressTitleRuleFacts facts =
        (factsResult as Success<ProgressTitleRuleFacts>).value;
    final ({int current, int best}) streaks = _calculateDailyStreaks(
      completionInstantsUtc: facts.completionInstantsUtc,
      localDay: localDay,
    );
    final List<ProgressTitleDecision> decisions = <ProgressTitleDecision>[];
    for (final definition in facts.definitions) {
      switch (definition.ruleKey) {
        case 'missions.completed.area.hogar':
          decisions.add(
            ProgressTitleDecision(
              titleId: definition.id,
              achieved:
                  definition.threshold > 0 &&
                  facts.completedHomeMissions >= definition.threshold,
              bestStreak: 0,
            ),
          );
        case 'missions.completed.daily_streak':
          decisions.add(
            ProgressTitleDecision(
              titleId: definition.id,
              achieved:
                  definition.threshold > 0 &&
                  streaks.current >= definition.threshold,
              bestStreak: streaks.best,
            ),
          );
      }
    }

    final titlesResult = await _progressRepository.synchronizeTitles(
      decisions: decisions,
      evaluatedAtUtc: nowUtc,
    );
    if (titlesResult is Failure<List<TitleProgressItem>>) {
      return Failure<_TitleSummary>(titlesResult.failure);
    }
    return Success<_TitleSummary>(
      _TitleSummary(
        activeTitles: (titlesResult as Success<List<TitleProgressItem>>).value,
        currentStreak: streaks.current,
        bestStreak: streaks.best,
      ),
    );
  }

  ({int current, int best}) _calculateDailyStreaks({
    required List<DateTime> completionInstantsUtc,
    required DateTime localDay,
  }) {
    final Set<DateTime> completionDays = completionInstantsUtc
        .map((instant) => instant.toLocal())
        .map(
          (instant) => DateTime.utc(instant.year, instant.month, instant.day),
        )
        .toSet();
    if (completionDays.isEmpty) {
      return (current: 0, best: 0);
    }

    final List<DateTime> orderedDays = completionDays.toList()..sort();
    int best = 1;
    int running = 1;
    for (int index = 1; index < orderedDays.length; index += 1) {
      if (orderedDays[index].difference(orderedDays[index - 1]).inDays == 1) {
        running += 1;
        if (running > best) {
          best = running;
        }
      } else {
        running = 1;
      }
    }

    final DateTime today = DateTime.utc(
      localDay.year,
      localDay.month,
      localDay.day,
    );
    DateTime cursor = completionDays.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    int current = 0;
    while (completionDays.contains(cursor)) {
      current += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return (current: current, best: best);
  }
}

final class _TitleSummary {
  const _TitleSummary({
    required this.activeTitles,
    required this.currentStreak,
    required this.bestStreak,
  });

  final List<TitleProgressItem> activeTitles;
  final int currentStreak;
  final int bestStreak;
}
