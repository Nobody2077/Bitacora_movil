import '../../../../core/result/result.dart';
import '../models/economy_snapshot.dart';

abstract interface class EconomyRepository {
  Future<Result<EconomySnapshot>> loadSnapshot({
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    required DateTime monthStartUtc,
    required DateTime monthEndUtc,
  });
}
