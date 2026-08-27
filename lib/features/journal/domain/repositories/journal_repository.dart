import '../../../../core/result/result.dart';
import '../models/journal_entry.dart';
import '../models/journal_photo.dart';

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

  Future<Result<List<JournalPhoto>>> findPhotos(String entryId);

  Future<Result<JournalPhoto>> addPhoto(JournalPhoto photo);

  Future<Result<JournalPhoto?>> archivePhoto({
    required String attachmentId,
    required DateTime archivedAtUtc,
  });

  Future<Result<Set<String>>> findActivePhotoStorageNames();
}
