import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/persistence_providers.dart';
import '../../../core/result/result.dart';
import '../domain/models/journal_entry.dart';
import '../domain/repositories/journal_repository.dart';
import 'journal_application_service.dart';

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

JournalRange journalDayRange(DateTime localDay) => (
  startUtc: DateTime(localDay.year, localDay.month, localDay.day).toUtc(),
  endUtc: DateTime(localDay.year, localDay.month, localDay.day + 1).toUtc(),
);
