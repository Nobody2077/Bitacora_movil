import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../infrastructure/database/daos/daily_close_dao.dart';
import '../domain/models/daily_close.dart';
import '../domain/repositories/daily_close_repository.dart';

final class DriftDailyCloseRepository implements DailyCloseRepository {
  const DriftDailyCloseRepository(this._dao);

  final DailyCloseDao _dao;

  @override
  Future<Result<DailyCloseSummary>> loadSummary({
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    required DateTime referenceUtc,
  }) async {
    if (!dayStartUtc.isUtc ||
        !dayEndUtc.isUtc ||
        !referenceUtc.isUtc ||
        !dayEndUtc.isAfter(dayStartUtc)) {
      return const Failure<DailyCloseSummary>(
        ValidationFailure('El día del cierre no es válido.'),
      );
    }
    try {
      final data = await _dao.load(
        dayStartUtcMs: dayStartUtc.millisecondsSinceEpoch,
        dayEndUtcMs: dayEndUtc.millisecondsSinceEpoch,
        referenceUtcMs: referenceUtc.millisecondsSinceEpoch,
      );
      return Success<DailyCloseSummary>(
        DailyCloseSummary(
          completedMissions: data.completedMissions
              .map(
                (mission) => DailyCloseMission(
                  id: mission.id,
                  title: mission.title,
                  isPartial: mission.status == 'PARTIAL',
                ),
              )
              .toList(growable: false),
          requiredPendingMissions: data.requiredPendingMissions
              .map(
                (mission) =>
                    DailyCloseMission(id: mission.id, title: mission.title),
              )
              .toList(growable: false),
          xpEarned: data.xpEarned,
          workSeconds: data.workSeconds,
          incomeMinor: data.incomeMinor,
          expenseMinor: data.expenseMinor,
          mainAreaName: data.mainAreaName,
        ),
      );
    } on Object catch (error) {
      return Failure<DailyCloseSummary>(
        StorageFailure('No se pudo calcular el cierre diario.', cause: error),
      );
    }
  }
}
