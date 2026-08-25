import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../infrastructure/database/daos/dao_support.dart';
import '../../../infrastructure/database/daos/mission_dao.dart';
import '../domain/models/mission.dart';
import '../domain/repositories/mission_repository.dart';
import 'mission_mapper.dart';

final class DriftMissionRepository implements MissionRepository {
  const DriftMissionRepository(this._dao);

  final MissionDao _dao;

  @override
  Future<Result<Mission?>> findById(String id) async {
    if (id.trim().isEmpty) {
      return const Failure<Mission?>(
        ValidationFailure('El identificador de misión es obligatorio.'),
      );
    }

    try {
      final aggregate = await _dao.getAggregate(id);
      return Success<Mission?>(
        MissionMapper.fromDrift(
          aggregate.mission,
          objectives: aggregate.objectives,
        ),
      );
    } on RecordNotFoundException {
      return const Success<Mission?>(null);
    } on Object catch (error) {
      return Failure<Mission?>(
        StorageFailure('No se pudo leer la misión.', cause: error),
      );
    }
  }

  @override
  Future<Result<List<Mission>>> findScheduledBetween({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    if (!startUtc.isUtc || !endUtc.isUtc || !endUtc.isAfter(startUtc)) {
      return const Failure<List<Mission>>(
        ValidationFailure(
          'El período de misiones debe usar límites UTC válidos.',
        ),
      );
    }

    try {
      final rows = await _dao
          .watchPeriod(
            startUtcMs: startUtc.millisecondsSinceEpoch,
            endUtcMs: endUtc.millisecondsSinceEpoch,
          )
          .first;
      return Success<List<Mission>>(
        rows.map(MissionMapper.fromDrift).toList(growable: false),
      );
    } on Object catch (error) {
      return Failure<List<Mission>>(
        StorageFailure('No se pudieron leer las misiones.', cause: error),
      );
    }
  }
}
