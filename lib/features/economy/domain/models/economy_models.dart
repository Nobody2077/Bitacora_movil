enum EconomyTransactionType {
  income,
  expense,
  refund,
  adjustmentCredit,
  adjustmentDebit,
}

enum EconomyPaymentMethod { cash, bank, wallet }

enum SavingsGoalStatus { active, achieved, paused, archived }

enum GoalAllocationDirection { reserve, release }

final class EconomyTransaction {
  const EconomyTransaction({
    required this.id,
    required this.operationId,
    required this.type,
    required this.amountMinor,
    required this.occurredAtUtc,
    required this.createdAtUtc,
    this.missionId,
    this.relatedTransactionId,
    this.paymentMethod,
    this.category,
    this.note,
    this.reversedAtUtc,
  });

  final String id;
  final String operationId;
  final String? missionId;
  final String? relatedTransactionId;
  final EconomyTransactionType type;
  final int amountMinor;
  final EconomyPaymentMethod? paymentMethod;
  final String? category;
  final String? note;
  final DateTime occurredAtUtc;
  final DateTime createdAtUtc;
  final DateTime? reversedAtUtc;

  bool get isCredit => const <EconomyTransactionType>{
    EconomyTransactionType.income,
    EconomyTransactionType.refund,
    EconomyTransactionType.adjustmentCredit,
  }.contains(type);

  bool get isReversal => relatedTransactionId != null;

  bool get isReversed => reversedAtUtc != null;
}

final class SavingsGoalSummary {
  const SavingsGoalSummary({
    required this.id,
    required this.title,
    required this.targetMinor,
    required this.reservedMinor,
    required this.status,
    required this.createdAtUtc,
    this.dueDate,
    this.archivedAtUtc,
  });

  final String id;
  final String title;
  final int targetMinor;
  final int reservedMinor;
  final SavingsGoalStatus status;
  final String? dueDate;
  final DateTime createdAtUtc;
  final DateTime? archivedAtUtc;

  int get remainingMinor => (targetMinor - reservedMinor).clamp(0, targetMinor);

  double get progress =>
      targetMinor == 0 ? 0 : (reservedMinor / targetMinor).clamp(0, 1);
}
