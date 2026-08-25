import '../../../../core/result/result.dart';
import '../models/journal_entry.dart';

abstract interface class JournalRepository {
  Future<Result<List<JournalEntry>>> findRecent({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 100,
  });

  Future<Result<JournalEntry?>> findById(String id);
}
