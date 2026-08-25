import '../../../../core/result/result.dart';
import '../models/progress_snapshot.dart';

abstract interface class ProgressRepository {
  Future<Result<ProgressSnapshot>> loadSnapshot({
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    required DateTime weekStartUtc,
  });
}
