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
    required this.rpgLevel,
  });

  final String areaId;
  final String areaName;
  final String colorHex;
  final String iconKey;
  final int amount;
  final double percentage;
  final RpgLevel rpgLevel;
}

enum ProgressTitleKind {
  permanent('PERMANENT'),
  dynamic('DYNAMIC'),
  temporary('TEMPORARY');

  const ProgressTitleKind(this.storageValue);

  final String storageValue;

  static ProgressTitleKind fromStorage(String value) => switch (value) {
    'PERMANENT' => ProgressTitleKind.permanent,
    'DYNAMIC' => ProgressTitleKind.dynamic,
    'TEMPORARY' => ProgressTitleKind.temporary,
    _ => throw ArgumentError.value(value, 'value', 'Unknown title kind.'),
  };
}

enum ProgressTitleStatus {
  active('ACTIVE'),
  earned('EARNED');

  const ProgressTitleStatus(this.storageValue);

  final String storageValue;

  static ProgressTitleStatus fromStorage(String value) => switch (value) {
    'ACTIVE' => ProgressTitleStatus.active,
    'EARNED' => ProgressTitleStatus.earned,
    _ => throw ArgumentError.value(value, 'value', 'Unknown title status.'),
  };
}

final class ProgressTitleDefinition {
  const ProgressTitleDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.kind,
    required this.ruleKey,
    required this.threshold,
  });

  final String id;
  final String name;
  final String? description;
  final ProgressTitleKind kind;
  final String ruleKey;
  final int threshold;
}

final class ProgressTitleRuleFacts {
  const ProgressTitleRuleFacts({
    required this.definitions,
    required this.completedHomeMissions,
    required this.completionInstantsUtc,
  });

  final List<ProgressTitleDefinition> definitions;
  final int completedHomeMissions;
  final List<DateTime> completionInstantsUtc;
}

final class ProgressTitleDecision {
  const ProgressTitleDecision({
    required this.titleId,
    required this.achieved,
    required this.bestStreak,
  });

  final String titleId;
  final bool achieved;
  final int bestStreak;
}

final class TitleProgressItem {
  const TitleProgressItem({
    required this.id,
    required this.name,
    required this.description,
    required this.kind,
    required this.status,
    required this.activatedAtUtc,
    this.bestStreak = 0,
    this.recoveryCount = 0,
  });

  final String id;
  final String name;
  final String? description;
  final ProgressTitleKind kind;
  final ProgressTitleStatus status;
  final DateTime activatedAtUtc;
  final int bestStreak;
  final int recoveryCount;
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
    this.currentStreak = 0,
    this.bestStreak = 0,
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
  final int currentStreak;
  final int bestStreak;

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
    this.currentStreak = 0,
    this.bestStreak = 0,
  });

  final RpgLevel rpgLevel;
  final int totalXp;
  final int todayXp;
  final int weekXp;
  final List<AreaProgressItem> areaBreakdown;
  final List<TitleProgressItem> activeTitles;
  final int currentStreak;
  final int bestStreak;
}
