import '../../../../core/result/result.dart';
import '../models/mission.dart';

abstract interface class MissionRepository {
  Future<Result<Mission?>> findById(String id);

  Future<Result<List<MissionArea>>> findVisibleAreas();

  Future<Result<List<Mission>>> findScheduledBetween({
    required DateTime startUtc,
    required DateTime endUtc,
  });

  Stream<Result<List<Mission>>> watchScheduledBetween({
    required DateTime startUtc,
    required DateTime endUtc,
  });

  Future<Result<Mission>> create(
    Mission mission, {
    required String eventId,
    required DateTime occurredAtUtc,
  });

  Future<Result<Mission>> update(
    Mission mission, {
    required String eventId,
    required DateTime occurredAtUtc,
  });
}
