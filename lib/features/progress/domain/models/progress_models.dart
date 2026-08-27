import '../../../journal/domain/models/daily_close.dart';
import 'rpg_level.dart';

final class AreaProgressItem {
  const AreaProgressItem({
    required this.areaId,
    required this.areaName,
    required this.colorHex,
    required this.iconKey,
    required this.amount,
    required this.percentage,
  });

  final String areaId;
  final String areaName;
  final String colorHex;
  final String iconKey;
  final int amount;
  final double percentage;
}

final class TitleProgressItem {
  const TitleProgressItem({
    required this.id,
    required this.name,
    required this.titleKind,
    this.bestStreak = 0,
  });

  final String id;
  final String name;
  final String titleKind;
  final int bestStreak;
}

final class DailyDashboardViewData {
  const DailyDashboardViewData({
    required this.localDay,
    required this.rpgLevel,
    required this.todayXp,
    required this.totalXp,
    required this.dailyCloseSummary,
  });

  final DateTime localDay;
  final RpgLevel rpgLevel;
  final int todayXp;
  final int totalXp;
  final DailyCloseSummary dailyCloseSummary;
}

final class WeeklyDashboardViewData {
  const WeeklyDashboardViewData({
    required this.weekStart,
    required this.weekEnd,
    required this.rpgLevel,
    required this.weekXp,
    required this.totalXp,
    required this.areaBreakdown,
    required this.completedMissionsCount,
    required this.totalWorkSeconds,
    required this.weekIncomeMinor,
    required this.weekExpenseMinor,
  });

  final DateTime weekStart;
  final DateTime weekEnd;
  final RpgLevel rpgLevel;
  final int weekXp;
  final int totalXp;
  final List<AreaProgressItem> areaBreakdown;
  final int completedMissionsCount;
  final int totalWorkSeconds;
  final int weekIncomeMinor;
  final int weekExpenseMinor;

  int get weekBalanceMinor => weekIncomeMinor - weekExpenseMinor;
}

final class OverallProgressViewData {
  const OverallProgressViewData({
    required this.rpgLevel,
    required this.totalXp,
    required this.todayXp,
    required this.weekXp,
    required this.areaBreakdown,
    this.activeTitles = const <TitleProgressItem>[],
  });

  final RpgLevel rpgLevel;
  final int totalXp;
  final int todayXp;
  final int weekXp;
  final List<AreaProgressItem> areaBreakdown;
  final List<TitleProgressItem> activeTitles;
}
