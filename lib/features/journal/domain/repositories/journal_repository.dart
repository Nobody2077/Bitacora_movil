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

  /// [contactIds] son los personajes propios de la entrada (ADR-006 D3).
  Future<Result<JournalEntry>> create(
    JournalEntry entry, {
    Iterable<String> contactIds = const <String>[],
  });

  /// Con [contactIds] `null` los personajes de la entrada no se tocan.
  Future<Result<JournalEntry>> update(
    JournalEntry entry, {
    Iterable<String>? contactIds,
  });

  Future<Result<List<JournalEntry>>> search(JournalSearchCriteria criteria);

  Stream<Result<List<JournalEntry>>> watchArchived({int limit = 200});

  Future<Result<JournalEntry>> archiveEntry({
    required String entryId,
    required DateTime archivedAtUtc,
    required DateTime updatedAtUtc,
  });

  Future<Result<JournalEntry>> restoreEntry({
    required String entryId,
    required DateTime updatedAtUtc,
  });

  Future<Result<List<JournalPhoto>>> findPhotos(String entryId);

  Future<Result<JournalPhoto>> addPhoto(JournalPhoto photo);

  Future<Result<JournalPhoto?>> archivePhoto({
    required String attachmentId,
    required DateTime archivedAtUtc,
  });

  Future<Result<Set<String>>> findActivePhotoStorageNames();
}
