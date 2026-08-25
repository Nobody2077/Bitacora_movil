final class AreaXp {
  const AreaXp({required this.areaId, required this.amount});

  final String areaId;
  final int amount;
}

/// Resumen de XP calculado para límites temporales inyectados.
final class ProgressSnapshot {
  const ProgressSnapshot({
    required this.totalXp,
    required this.todayXp,
    required this.weekXp,
    required this.byArea,
  });

  final int totalXp;
  final int todayXp;
  final int weekXp;
  final List<AreaXp> byArea;
}
