import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/persistence_providers.dart';
import '../../../core/result/result.dart';
import '../../journal/application/journal_providers.dart';
import '../domain/models/contact.dart';
import 'contact_application_service.dart';

final Provider<ContactApplicationService> contactApplicationServiceProvider =
    Provider<ContactApplicationService>(
      (Ref ref) => ContactApplicationService(
        repository: ref.watch(contactRepositoryProvider),
        clock: ref.watch(journalClockProvider),
        idGenerator: ref.watch(journalIdGeneratorProvider),
      ),
    );

final StreamProvider<List<Contact>> activeContactsProvider =
    StreamProvider<List<Contact>>(
      (Ref ref) => ref
          .watch(contactRepositoryProvider)
          .watchActive()
          .map(_unwrap<List<Contact>>),
    );

final StreamProvider<List<Contact>> archivedContactsProvider =
    StreamProvider<List<Contact>>(
      (Ref ref) => ref
          .watch(contactRepositoryProvider)
          .watchArchived()
          .map(_unwrap<List<Contact>>),
    );

final contactProvider = StreamProvider.family<Contact?, String>(
  (Ref ref, String id) =>
      ref.watch(contactRepositoryProvider).watchById(id).map(_unwrap<Contact?>),
);

final missionContactsProvider = FutureProvider.family<List<Contact>, String>((
  Ref ref,
  String missionId,
) async {
  final Result<List<Contact>> result = await ref
      .watch(contactRepositoryProvider)
      .findForMission(missionId);
  return _unwrap(result);
});

final contactMissionIdsProvider = StreamProvider.family<List<String>, String>(
  (Ref ref, String contactId) => ref
      .watch(contactRepositoryProvider)
      .watchMissionIdsForContact(contactId)
      .map(_unwrap<List<String>>),
);

final contactJournalEntryIdsProvider =
    StreamProvider.family<List<String>, String>(
      (Ref ref, String contactId) => ref
          .watch(contactRepositoryProvider)
          .watchJournalEntryIdsForContact(contactId)
          .map(_unwrap<List<String>>),
    );

/// Conjunto de ids con igualdad por valor, para usarlo como clave de familia.
final class IdSet {
  IdSet(Iterable<String> ids) : ids = Set<String>.unmodifiable(ids);

  final Set<String> ids;

  @override
  bool operator ==(Object other) =>
      other is IdSet &&
      other.ids.length == ids.length &&
      other.ids.containsAll(ids);

  @override
  int get hashCode => Object.hashAllUnordered(ids);
}

/// Personajes de cada misión pedida (para tarjetas y listas).
final missionsContactsProvider =
    StreamProvider.family<Map<String, List<Contact>>, IdSet>(
      (Ref ref, IdSet missionIds) => ref
          .watch(contactRepositoryProvider)
          .watchForMissions(missionIds.ids)
          .map(_unwrap<Map<String, List<Contact>>>),
    );

/// Personajes de cada entrada: los suyos más los de su misión.
final journalEntriesContactsProvider =
    StreamProvider.family<Map<String, List<Contact>>, IdSet>(
      (Ref ref, IdSet entryIds) => ref
          .watch(contactRepositoryProvider)
          .watchForJournalEntries(entryIds.ids)
          .map(_unwrap<Map<String, List<Contact>>>),
    );

/// Solo los vinculados a la entrada; lo que su formulario puede editar.
final journalEntryOwnContactsProvider =
    FutureProvider.family<List<Contact>, String>((
      Ref ref,
      String entryId,
    ) async {
      final Result<List<Contact>> result = await ref
          .watch(contactRepositoryProvider)
          .findOwnForJournalEntry(entryId);
      return _unwrap(result);
    });

T _unwrap<T>(Result<T> result) => result.fold(
  onSuccess: (T value) => value,
  onFailure: (failure) => throw failure,
);
