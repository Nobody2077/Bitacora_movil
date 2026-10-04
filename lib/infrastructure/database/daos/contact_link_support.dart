import 'package:drift/drift.dart';

import '../app_database.dart';
import 'dao_support.dart';

/// Personajes que deben quedar vinculados a una misión o entrada, y el
/// instante con el que se registran los vínculos nuevos.
final class ContactLinksWrite {
  ContactLinksWrite({
    required Iterable<String> contactIds,
    required this.createdAtUtcMs,
  }) : contactIds = Set<String>.unmodifiable(contactIds) {
    if (this.contactIds.length > maxLinks) {
      throw ArgumentError.value(
        this.contactIds.length,
        'contactIds',
        'At most $maxLinks contacts per record.',
      );
    }
    if (this.contactIds.any((String id) => id.trim().isEmpty)) {
      throw ArgumentError('Contact ids must not be empty.');
    }
  }

  static const int maxLinks = 50;

  final Set<String> contactIds;
  final int createdAtUtcMs;
}

enum ContactLinkTarget { mission, journalEntry }

/// Deja exactamente [links] como personajes de [ownerId].
///
/// Conserva la fecha de los vínculos que siguen y solo exige personaje activo
/// para los vínculos **nuevos**: archivar un personaje no rompe las misiones ni
/// las entradas donde ya aparecía. Debe ejecutarse dentro de la transacción de
/// quien escribe la misión o la entrada.
Future<void> replaceContactLinks(
  AppDatabase database, {
  required ContactLinkTarget target,
  required String ownerId,
  required ContactLinksWrite links,
}) async {
  final Set<String> current = await currentContactLinkIds(
    database,
    target: target,
    ownerId: ownerId,
  );
  final Set<String> removed = current.difference(links.contactIds);
  final Set<String> added = links.contactIds.difference(current);

  if (removed.isNotEmpty) {
    switch (target) {
      case ContactLinkTarget.mission:
        await (database.delete(database.missionContacts)..where(
              (table) =>
                  table.missionId.equals(ownerId) &
                  table.contactId.isIn(removed),
            ))
            .go();
      case ContactLinkTarget.journalEntry:
        await (database.delete(database.journalEntryContacts)..where(
              (table) =>
                  table.journalEntryId.equals(ownerId) &
                  table.contactId.isIn(removed),
            ))
            .go();
    }
  }

  if (added.isEmpty) {
    return;
  }
  final List<Contact> active = await (database.select(
    database.contacts,
  )..where((table) => table.id.isIn(added) & table.archivedAt.isNull())).get();
  if (active.length != added.length) {
    final Set<String> found = active.map((Contact row) => row.id).toSet();
    throw InactiveContactLinkException(added.difference(found));
  }
  for (final String contactId in added) {
    switch (target) {
      case ContactLinkTarget.mission:
        await database
            .into(database.missionContacts)
            .insert(
              MissionContactsCompanion.insert(
                missionId: ownerId,
                contactId: contactId,
                createdAt: links.createdAtUtcMs,
              ),
            );
      case ContactLinkTarget.journalEntry:
        await database
            .into(database.journalEntryContacts)
            .insert(
              JournalEntryContactsCompanion.insert(
                journalEntryId: ownerId,
                contactId: contactId,
                createdAt: links.createdAtUtcMs,
              ),
            );
    }
  }
}

Future<Set<String>> currentContactLinkIds(
  AppDatabase database, {
  required ContactLinkTarget target,
  required String ownerId,
}) async {
  switch (target) {
    case ContactLinkTarget.mission:
      final List<MissionContact> rows = await (database.select(
        database.missionContacts,
      )..where((table) => table.missionId.equals(ownerId))).get();
      return rows.map((MissionContact row) => row.contactId).toSet();
    case ContactLinkTarget.journalEntry:
      final List<JournalEntryContact> rows = await (database.select(
        database.journalEntryContacts,
      )..where((table) => table.journalEntryId.equals(ownerId))).get();
      return rows.map((JournalEntryContact row) => row.contactId).toSet();
  }
}
