final class DailyCloseMission {
  const DailyCloseMission({
    required this.id,
    required this.title,
    this.isPartial = false,
  });

  final String id;
  final String title;
  final bool isPartial;
}

/// Resumen calculado para un día civil. No se persiste ni genera XP.
final class DailyCloseSummary {
  const DailyCloseSummary({
    required this.completedMissions,
    required this.requiredPendingMissions,
    required this.xpEarned,
    required this.workSeconds,
    required this.incomeMinor,
    required this.expenseMinor,
    this.mainAreaName,
  });

  final List<DailyCloseMission> completedMissions;
  final List<DailyCloseMission> requiredPendingMissions;
  final int xpEarned;
  final int workSeconds;
  final int incomeMinor;
  final int expenseMinor;
  final String? mainAreaName;

  int get balanceMinor => incomeMinor - expenseMinor;
}
