import '../../../../core/result/result.dart';
import '../models/progress_models.dart';
import '../models/progress_snapshot.dart';

abstract interface class ProgressRepository {
  Future<Result<ProgressSnapshot>> loadSnapshot({
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    required DateTime weekStartUtc,
  });

  Future<Result<ProgressTitleRuleFacts>> loadTitleRuleFacts();

  Future<Result<List<TitleProgressItem>>> synchronizeTitles({
    required List<ProgressTitleDecision> decisions,
    required DateTime evaluatedAtUtc,
  });

  Stream<void> watchChanges();
}
