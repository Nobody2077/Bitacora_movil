import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/persistence_providers.dart';
import '../../../core/result/result.dart';
import '../domain/models/economy_models.dart';
import '../domain/models/economy_snapshot.dart';
import '../domain/repositories/economy_repository.dart';
import 'economy_application_service.dart';

final Provider<EconomyClock> economyClockProvider = Provider<EconomyClock>(
  (Ref ref) => const SystemEconomyClock(),
);

final Provider<EconomyIdGenerator> economyIdGeneratorProvider =
    Provider<EconomyIdGenerator>((Ref ref) => SecureEconomyIdGenerator());

final Provider<EconomyApplicationService> economyApplicationServiceProvider =
    Provider<EconomyApplicationService>(
      (Ref ref) => EconomyApplicationService(
        repository: ref.watch(economyRepositoryProvider),
        clock: ref.watch(economyClockProvider),
        idGenerator: ref.watch(economyIdGeneratorProvider),
      ),
    );

typedef EconomyPeriods = ({
  DateTime dayStartUtc,
  DateTime dayEndUtc,
  DateTime monthStartUtc,
  DateTime monthEndUtc,
});

EconomyPeriods currentEconomyPeriods([DateTime? localNow]) {
  final now = localNow ?? DateTime.now();
  return (
    dayStartUtc: DateTime(now.year, now.month, now.day).toUtc(),
    dayEndUtc: DateTime(now.year, now.month, now.day + 1).toUtc(),
    monthStartUtc: DateTime(now.year, now.month).toUtc(),
    monthEndUtc: DateTime(now.year, now.month + 1).toUtc(),
  );
}

final StreamProvider<EconomySnapshot> economySnapshotProvider =
    StreamProvider<EconomySnapshot>((Ref ref) {
      final periods = currentEconomyPeriods();
      return ref
          .watch(economyRepositoryProvider)
          .watchSnapshot(
            dayStartUtc: periods.dayStartUtc,
            dayEndUtc: periods.dayEndUtc,
            monthStartUtc: periods.monthStartUtc,
            monthEndUtc: periods.monthEndUtc,
          )
          .map(
            (result) => result.fold(
              onSuccess: (value) => value,
              onFailure: (failure) => throw failure,
            ),
          );
    });

final StreamProvider<List<EconomyTransaction>> economyTransactionsProvider =
    StreamProvider<List<EconomyTransaction>>((Ref ref) {
      final EconomyRepository repository = ref.watch(economyRepositoryProvider);
      return repository
          .watchTransactions(
            startUtc: DateTime.utc(1970),
            endUtc: DateTime.utc(2200),
            limit: 500,
          )
          .map(
            (result) => result.fold(
              onSuccess: (value) => value,
              onFailure: (failure) => throw failure,
            ),
          );
    });

final StreamProvider<List<SavingsGoalSummary>> savingsGoalsProvider =
    StreamProvider<List<SavingsGoalSummary>>((Ref ref) {
      return ref
          .watch(economyRepositoryProvider)
          .watchGoals()
          .map(
            (result) => result.fold(
              onSuccess: (value) => value,
              onFailure: (failure) => throw failure,
            ),
          );
    });

final economyTransactionDetailProvider =
    FutureProvider.family<EconomyTransaction?, String>((
      Ref ref,
      String id,
    ) async {
      final Result<EconomyTransaction?> result = await ref
          .watch(economyRepositoryProvider)
          .findTransaction(id);
      return result.fold(
        onSuccess: (value) => value,
        onFailure: (failure) => throw failure,
      );
    });

final savingsGoalDetailProvider =
    FutureProvider.family<SavingsGoalSummary?, String>((
      Ref ref,
      String id,
    ) async {
      final Result<SavingsGoalSummary?> result = await ref
          .watch(economyRepositoryProvider)
          .findGoal(id);
      return result.fold(
        onSuccess: (value) => value,
        onFailure: (failure) => throw failure,
      );
    });
