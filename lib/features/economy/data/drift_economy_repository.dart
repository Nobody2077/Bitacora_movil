import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../infrastructure/database/daos/economy_dao.dart';
import '../domain/models/economy_snapshot.dart';
import '../domain/repositories/economy_repository.dart';

final class DriftEconomyRepository implements EconomyRepository {
  const DriftEconomyRepository(this._dao);

  final EconomyDao _dao;

  @override
  Future<Result<EconomySnapshot>> loadSnapshot({
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    required DateTime monthStartUtc,
    required DateTime monthEndUtc,
  }) async {
    if (!_validRange(dayStartUtc, dayEndUtc) ||
        !_validRange(monthStartUtc, monthEndUtc)) {
      return const Failure<EconomySnapshot>(
        ValidationFailure(
          'Los períodos económicos deben usar límites UTC válidos.',
        ),
      );
    }

    try {
      final balanceFuture = _dao.watchBalance().first;
      final monthFuture = _dao.totalsForPeriod(
        startUtcMs: monthStartUtc.millisecondsSinceEpoch,
        endUtcMs: monthEndUtc.millisecondsSinceEpoch,
      );
      final dayFuture = _dao.totalsForPeriod(
        startUtcMs: dayStartUtc.millisecondsSinceEpoch,
        endUtcMs: dayEndUtc.millisecondsSinceEpoch,
      );

      final balance = await balanceFuture;
      final month = await monthFuture;
      final day = await dayFuture;
      return Success<EconomySnapshot>(
        EconomySnapshot(
          totalMinor: balance.totalMinor,
          reservedMinor: balance.reservedMinor,
          monthIncomeMinor: month.incomeMinor,
          monthExpenseMinor: month.expenseMinor,
          dayIncomeMinor: day.incomeMinor,
          dayExpenseMinor: day.expenseMinor,
        ),
      );
    } on Object catch (error) {
      return Failure<EconomySnapshot>(
        StorageFailure('No se pudo leer el resumen económico.', cause: error),
      );
    }
  }

  static bool _validRange(DateTime start, DateTime end) =>
      start.isUtc && end.isUtc && end.isAfter(start);
}
