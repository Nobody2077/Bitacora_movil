import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../infrastructure/database/daos/progress_dao.dart';
import '../domain/models/progress_snapshot.dart';
import '../domain/repositories/progress_repository.dart';

final class DriftProgressRepository implements ProgressRepository {
  const DriftProgressRepository(this._dao);

  final ProgressDao _dao;

  @override
  Future<Result<ProgressSnapshot>> loadSnapshot({
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    required DateTime weekStartUtc,
  }) async {
    if (!dayStartUtc.isUtc ||
        !dayEndUtc.isUtc ||
        !weekStartUtc.isUtc ||
        !dayEndUtc.isAfter(dayStartUtc) ||
        weekStartUtc.isAfter(dayStartUtc)) {
      return const Failure<ProgressSnapshot>(
        ValidationFailure(
          'Los períodos de progreso deben usar límites UTC válidos.',
        ),
      );
    }

    try {
      final todayFuture = _dao
          .watchTotals(
            periodStartUtcMs: dayStartUtc.millisecondsSinceEpoch,
            periodEndUtcMs: dayEndUtc.millisecondsSinceEpoch,
          )
          .first;
      final weekFuture = _dao
          .watchTotals(
            periodStartUtcMs: weekStartUtc.millisecondsSinceEpoch,
            periodEndUtcMs: dayEndUtc.millisecondsSinceEpoch,
          )
          .first;
      final areasFuture = _dao.watchAreaTotals().first;

      final today = await todayFuture;
      final week = await weekFuture;
      final areas = await areasFuture;
      return Success<ProgressSnapshot>(
        ProgressSnapshot(
          totalXp: today.effectiveTotal,
          todayXp: today.effectivePeriodTotal,
          weekXp: week.effectivePeriodTotal,
          byArea: areas
              .map(
                (area) =>
                    AreaXp(areaId: area.areaId, amount: area.effectiveTotal),
              )
              .toList(growable: false),
        ),
      );
    } on Object catch (error) {
      return Failure<ProgressSnapshot>(
        StorageFailure('No se pudo leer el progreso.', cause: error),
      );
    }
  }
}
