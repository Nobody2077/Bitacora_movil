import '../../../../core/result/result.dart';
import '../models/daily_close.dart';

abstract interface class DailyCloseRepository {
  Future<Result<DailyCloseSummary>> loadSummary({
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    required DateTime referenceUtc,
  });
}
