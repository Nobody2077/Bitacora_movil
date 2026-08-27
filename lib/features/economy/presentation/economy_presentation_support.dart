import '../domain/models/economy_models.dart';

String economyMoney(int minor, {bool signed = false}) {
  final bool negative = minor < 0;
  final int absolute = minor.abs();
  final String whole = (absolute ~/ 100).toString();
  final String decimals = (absolute % 100).toString().padLeft(2, '0');
  final String sign = negative ? '-' : (signed && minor > 0 ? '+' : '');
  return '$sign Bs $whole,$decimals';
}

int? parseEconomyMoney(String value) {
  final String normalized = value
      .trim()
      .replaceAll(' ', '')
      .replaceAll(',', '.');
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(normalized);
  if (match == null) {
    return null;
  }
  final int units = int.parse(match.group(1)!);
  final String decimals = (match.group(2) ?? '').padRight(2, '0');
  return units * 100 + (decimals.isEmpty ? 0 : int.parse(decimals));
}

String economyTransactionTypeLabel(EconomyTransactionType value) =>
    switch (value) {
      EconomyTransactionType.income => 'Ingreso',
      EconomyTransactionType.expense => 'Gasto',
      EconomyTransactionType.refund => 'Reembolso',
      EconomyTransactionType.adjustmentCredit => 'Ajuste a favor',
      EconomyTransactionType.adjustmentDebit => 'Ajuste en contra',
    };

String economyPaymentLabel(EconomyPaymentMethod value) => switch (value) {
  EconomyPaymentMethod.cash => 'Efectivo',
  EconomyPaymentMethod.bank => 'Banco',
  EconomyPaymentMethod.wallet => 'Billetera',
};

String economyGoalStatusLabel(SavingsGoalStatus value) => switch (value) {
  SavingsGoalStatus.active => 'Activa',
  SavingsGoalStatus.achieved => 'Alcanzada',
  SavingsGoalStatus.paused => 'Pausada',
  SavingsGoalStatus.archived => 'Archivada',
};

String economyDateTimeLabel(DateTime utc) {
  final local = utc.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year} · '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String? economyPositiveMoneyValidator(String? value) {
  final int? parsed = parseEconomyMoney(value ?? '');
  return parsed == null || parsed <= 0
      ? 'Escribe un monto mayor que cero.'
      : null;
}
