import '../../../../core/result/result.dart';
import '../models/economy_models.dart';
import '../models/economy_snapshot.dart';

abstract interface class EconomyRepository {
  Future<Result<EconomySnapshot>> loadSnapshot({
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    required DateTime monthStartUtc,
    required DateTime monthEndUtc,
  });

  Stream<Result<EconomySnapshot>> watchSnapshot({
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    required DateTime monthStartUtc,
    required DateTime monthEndUtc,
  });

  Stream<Result<List<EconomyTransaction>>> watchTransactions({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 100,
  });

  Future<Result<EconomyTransaction?>> findTransaction(String id);

  Future<Result<EconomyTransaction>> createTransaction({
    required EconomyTransaction transaction,
  });

  Future<Result<EconomyTransaction>> reverseTransaction({
    required EconomyTransaction original,
    required EconomyTransaction reversal,
    required DateTime reversedAtUtc,
  });

  Future<Result<EconomyTransaction>> correctTransaction({
    required EconomyTransaction original,
    required EconomyTransaction reversal,
    required EconomyTransaction replacement,
    required DateTime reversedAtUtc,
  });

  Stream<Result<List<SavingsGoalSummary>>> watchGoals();

  Future<Result<SavingsGoalSummary?>> findGoal(String id);

  Future<Result<SavingsGoalSummary>> createGoal(SavingsGoalSummary goal);

  Future<Result<SavingsGoalSummary>> updateGoal(SavingsGoalSummary goal);

  Future<Result<SavingsGoalSummary>> allocate({
    required String allocationId,
    required String operationId,
    required String goalId,
    required GoalAllocationDirection direction,
    required int amountMinor,
    required DateTime occurredAtUtc,
    String? note,
  });
}
