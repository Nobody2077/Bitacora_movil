import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/providers/persistence_providers.dart';
import '../../../core/result/result.dart';
import '../data/encrypted_journal_photo_store.dart';
import '../domain/models/journal_entry.dart';
import '../domain/models/journal_photo.dart';
import '../domain/repositories/journal_repository.dart';
import 'daily_close_application_service.dart';
import 'journal_application_service.dart';
import 'journal_photo_application_service.dart';

final Provider<JournalClock> journalClockProvider = Provider<JournalClock>(
  (Ref ref) => const SystemJournalClock(),
);

final Provider<JournalIdGenerator> journalIdGeneratorProvider =
    Provider<JournalIdGenerator>((Ref ref) => SecureJournalIdGenerator());

final Provider<JournalApplicationService> journalApplicationServiceProvider =
    Provider<JournalApplicationService>(
      (Ref ref) => JournalApplicationService(
        repository: ref.watch(journalRepositoryProvider),
        clock: ref.watch(journalClockProvider),
        idGenerator: ref.watch(journalIdGeneratorProvider),
      ),
    );

final Provider<DailyCloseApplicationService>
dailyCloseApplicationServiceProvider = Provider<DailyCloseApplicationService>(
  (Ref ref) => DailyCloseApplicationService(
    dailyCloseRepository: ref.watch(dailyCloseRepositoryProvider),
    journalRepository: ref.watch(journalRepositoryProvider),
    clock: ref.watch(journalClockProvider),
  ),
);

final dailyCloseProvider = FutureProvider.family<DailyCloseViewData, DateTime>((
  Ref ref,
  DateTime localDay,
) async {
  final result = await ref
      .watch(dailyCloseApplicationServiceProvider)
      .load(localDay);
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (failure) => throw failure,
  );
});

final Provider<JournalPhotoStore> journalPhotoStoreProvider =
    Provider<JournalPhotoStore>(
      (Ref ref) => EncryptedJournalPhotoStore(
        keyStore: ref.watch(databaseKeyStoreProvider),
        directoryLocator: getApplicationSupportDirectory,
      ),
    );

final Provider<JournalPhotoApplicationService>
journalPhotoApplicationServiceProvider =
    Provider<JournalPhotoApplicationService>(
      (Ref ref) => JournalPhotoApplicationService(
        repository: ref.watch(journalRepositoryProvider),
        photoStore: ref.watch(journalPhotoStoreProvider),
        picker: ImagePickerJournalPhotoPicker(ImagePicker()),
        clock: ref.watch(journalClockProvider),
        idGenerator: ref.watch(journalIdGeneratorProvider),
      ),
    );

typedef JournalRange = ({DateTime startUtc, DateTime endUtc});

final journalEntriesProvider =
    StreamProvider.family<List<JournalEntry>, JournalRange>((
      Ref ref,
      JournalRange range,
    ) {
      final JournalRepository repository = ref.watch(journalRepositoryProvider);
      return repository
          .watchRecent(startUtc: range.startUtc, endUtc: range.endUtc)
          .map(
            (Result<List<JournalEntry>> result) => result.fold(
              onSuccess: (List<JournalEntry> entries) => entries,
              onFailure: (failure) => throw failure,
            ),
          );
    });

final journalEntryDetailProvider = FutureProvider.family<JournalEntry?, String>(
  (Ref ref, String id) async {
    final Result<JournalEntry?> result = await ref
        .watch(journalRepositoryProvider)
        .findById(id);
    return result.fold(
      onSuccess: (JournalEntry? entry) => entry,
      onFailure: (failure) => throw failure,
    );
  },
);

final journalSearchProvider =
    FutureProvider.family<List<JournalEntry>, JournalSearchCriteria>((
      Ref ref,
      JournalSearchCriteria criteria,
    ) async {
      final Result<List<JournalEntry>> result = await ref
          .watch(journalRepositoryProvider)
          .search(criteria);
      return result.fold(
        onSuccess: (entries) => entries,
        onFailure: (failure) => throw failure,
      );
    });

final StreamProvider<List<JournalEntry>> archivedJournalEntriesProvider =
    StreamProvider<List<JournalEntry>>((Ref ref) {
      return ref
          .watch(journalRepositoryProvider)
          .watchArchived()
          .map(
            (Result<List<JournalEntry>> result) => result.fold(
              onSuccess: (entries) => entries,
              onFailure: (failure) => throw failure,
            ),
          );
    });

final journalPhotosProvider = FutureProvider.family<List<JournalPhoto>, String>(
  (Ref ref, String entryId) async {
    final Result<List<JournalPhoto>> result = await ref
        .watch(journalRepositoryProvider)
        .findPhotos(entryId);
    return result.fold(
      onSuccess: (photos) => photos,
      onFailure: (failure) => throw failure,
    );
  },
);

final journalPhotoBytesProvider =
    FutureProvider.family<Uint8List, JournalPhoto>((
      Ref ref,
      JournalPhoto photo,
    ) async {
      final Result<Uint8List> result = await ref
          .watch(journalPhotoApplicationServiceProvider)
          .read(photo);
      return result.fold(
        onSuccess: (bytes) => bytes,
        onFailure: (failure) => throw failure,
      );
    });

final FutureProvider<int> journalPhotoCleanupProvider = FutureProvider<int>((
  Ref ref,
) async {
  final Result<int> result = await ref
      .watch(journalPhotoApplicationServiceProvider)
      .cleanOrphans();
  return result.fold(
    onSuccess: (removed) => removed,
    onFailure: (failure) => throw failure,
  );
});

JournalRange journalDayRange(DateTime localDay) => (
  startUtc: DateTime(localDay.year, localDay.month, localDay.day).toUtc(),
  endUtc: DateTime(localDay.year, localDay.month, localDay.day + 1).toUtc(),
);
