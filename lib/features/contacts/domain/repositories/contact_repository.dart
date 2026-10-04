import '../../../../core/result/result.dart';
import '../models/contact.dart';

abstract interface class ContactRepository {
  Stream<Result<List<Contact>>> watchActive();

  Stream<Result<List<Contact>>> watchArchived();

  Future<Result<Contact?>> findById(String id);

  Stream<Result<Contact?>> watchById(String id);

  Future<Result<Contact>> create(Contact contact);

  /// Guarda nombre, rol y descripción si [Contact.rowVersion] sigue vigente.
  Future<Result<Contact>> update(Contact contact);

  Future<Result<Contact>> archive(Contact contact, {required DateTime atUtc});

  Future<Result<Contact>> restore(Contact contact, {required DateTime atUtc});

  Future<Result<List<Contact>>> findForMission(String missionId);

  /// Personajes de cada misión pedida; las que no tienen no aparecen.
  Stream<Result<Map<String, List<Contact>>>> watchForMissions(
    Set<String> missionIds,
  );

  /// Solo los vinculados a la entrada, sin los de su misión.
  Future<Result<List<Contact>>> findOwnForJournalEntry(String entryId);

  /// Los de cada entrada **más** los de su misión, sin repetir.
  Stream<Result<Map<String, List<Contact>>>> watchForJournalEntries(
    Set<String> entryIds,
  );

  Stream<Result<List<String>>> watchMissionIdsForContact(String contactId);

  Stream<Result<List<String>>> watchJournalEntryIdsForContact(String contactId);
}
