import '../../../../core/result/result.dart';
import '../models/mission.dart';

abstract interface class MissionRepository {
  Future<Result<Mission?>> findById(String id);

  Future<Result<List<Mission>>> findScheduledBetween({
    required DateTime startUtc,
    required DateTime endUtc,
  });
}
