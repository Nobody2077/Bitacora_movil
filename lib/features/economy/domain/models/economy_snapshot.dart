/// Resumen monetario en unidades menores de la moneda configurada.
final class EconomySnapshot {
  const EconomySnapshot({
    required this.totalMinor,
    required this.reservedMinor,
    required this.monthIncomeMinor,
    required this.monthExpenseMinor,
    required this.dayIncomeMinor,
    required this.dayExpenseMinor,
  });

  final int totalMinor;
  final int reservedMinor;
  final int monthIncomeMinor;
  final int monthExpenseMinor;
  final int dayIncomeMinor;
  final int dayExpenseMinor;

  int get availableMinor => totalMinor - reservedMinor;

  int get monthNetMinor => monthIncomeMinor - monthExpenseMinor;

  int get dayNetMinor => dayIncomeMinor - dayExpenseMinor;
}
