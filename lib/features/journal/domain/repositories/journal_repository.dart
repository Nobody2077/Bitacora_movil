import '../../../../core/result/result.dart';
import '../models/journal_entry.dart';

abstract interface class JournalRepository {
  Stream<Result<List<JournalEntry>>> watchRecent({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 100,
  });

  Future<Result<List<JournalEntry>>> findRecent({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 100,
  });

  Future<Result<JournalEntry?>> findById(String id);

  Future<Result<JournalEntry>> create(JournalEntry entry);

  Future<Result<JournalEntry>> update(JournalEntry entry);
}
