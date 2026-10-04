import 'package:drift/drift.dart';

import '../app_database.dart';
import 'dao_support.dart';

/// Personajes del Diario (ADR-006 D3) y sus vínculos con misiones y entradas.
///
/// Nunca borra: eliminar un personaje es archivarlo, y sus vínculos se quedan
/// para que las misiones y entradas pasadas sigan mostrando quién estuvo.
final class ContactDao {
  ContactDao(this._database);

  final AppDatabase _database;

  /// Límite de identificadores por consulta `IN (...)`, holgado frente al
  /// máximo de variables de SQLite.
  static const int maxBatchIds = 400;

  Future<Contact?> findById(String id) {
    return (_database.select(
      _database.contacts,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Stream<Contact?> watchById(String id) {
    return (_database.select(
      _database.contacts,
    )..where((table) => table.id.equals(id))).watchSingleOrNull();
  }

  /// Activos por nombre (sin distinguir mayúsculas); los que no tienen nombre
  /// van al final, del más antiguo al más nuevo.
  Stream<List<Contact>> watchActive() {
    return (_database.select(_database.contacts)
          ..where((table) => table.archivedAt.isNull())
          ..orderBy(_byName))
        .watch();
  }

  Stream<List<Contact>> watchArchived() {
    return (_database.select(_database.contacts)
          ..where((table) => table.archivedAt.isNotNull())
          ..orderBy(<OrderingTerm Function(Contacts)>[
            (table) => OrderingTerm.desc(table.archivedAt),
            (table) => OrderingTerm.asc(table.id),
          ]))
        .watch();
  }

  /// Inserta un personaje con un id generado por el cliente.
  ///
  /// Repetir la misma inserción (mismo id y mismos datos) es idempotente y
  /// devuelve la fila existente con `created: false`; el mismo id con datos
  /// distintos es un conflicto.
  Future<DaoWriteResult<Contact>> insertContact(ContactsCompanion contact) {
    if (!contact.id.present) {
      throw ArgumentError('Contact id must be present.');
    }
    if (contact.rowVersion.present || contact.archivedAt.present) {
      throw ArgumentError('row_version and archived_at are set by ContactDao.');
    }
    final String id = contact.id.value;
    return _database.transaction(() async {
      final Contact? existing = await findById(id);
      if (existing != null) {
        if (_sameContent(existing, contact)) {
          return DaoWriteResult<Contact>(value: existing, created: false);
        }
        throw IdempotencyConflictException(operationId: id, entity: 'contact');
      }
      await _database.into(_database.contacts).insert(contact);
      return DaoWriteResult<Contact>(value: await _require(id), created: true);
    });
  }

  /// Cambia nombre, rol y descripción con bloqueo optimista.
  Future<Contact> updateContact({
    required String contactId,
    required int expectedRowVersion,
    required ContactsCompanion changes,
  }) {
    if (changes.id.present ||
        changes.rowVersion.present ||
        changes.archivedAt.present ||
        changes.createdAt.present) {
      throw ArgumentError(
        'id, created_at, archived_at and row_version are set by ContactDao.',
      );
    }
    return _database.transaction(
      () => _writeWithRowVersion(
        contactId: contactId,
        expectedRowVersion: expectedRowVersion,
        changes: changes,
      ),
    );
  }

  Future<Contact> archiveContact({
    required String contactId,
    required int expectedRowVersion,
    required int archivedAtUtcMs,
  }) {
    return _database.transaction(() async {
      final Contact current = await _require(contactId);
      if (current.archivedAt != null) {
        throw DatabaseInvariantException('Contact $contactId is archived.');
      }
      return _writeWithRowVersion(
        contactId: contactId,
        expectedRowVersion: expectedRowVersion,
        changes: ContactsCompanion(
          archivedAt: Value<int?>(archivedAtUtcMs),
          updatedAt: Value<int>(archivedAtUtcMs),
        ),
      );
    });
  }

  Future<Contact> restoreContact({
    required String contactId,
    required int expectedRowVersion,
    required int updatedAtUtcMs,
  }) {
    return _database.transaction(() async {
      final Contact current = await _require(contactId);
      if (current.archivedAt == null) {
        throw DatabaseInvariantException('Contact $contactId is not archived.');
      }
      return _writeWithRowVersion(
        contactId: contactId,
        expectedRowVersion: expectedRowVersion,
        changes: ContactsCompanion(
          archivedAt: const Value<int?>(null),
          updatedAt: Value<int>(updatedAtUtcMs),
        ),
      );
    });
  }

  /// Personajes propios de la misión, en el orden en que se vincularon.
  Future<List<Contact>> findForMission(String missionId) async {
    final Map<String, List<Contact>> grouped = await _forMissionsQuery(<String>{
      missionId,
    }).get().then(_groupRows);
    return grouped[missionId] ?? const <Contact>[];
  }

  /// Personajes de cada misión pedida; las misiones sin personajes no
  /// aparecen en el mapa.
  Stream<Map<String, List<Contact>>> watchForMissions(Set<String> missionIds) {
    if (missionIds.isEmpty) {
      return Stream<Map<String, List<Contact>>>.value(
        const <String, List<Contact>>{},
      );
    }
    return _forMissionsQuery(missionIds).watch().map(_groupRows);
  }

  /// Personajes vinculados directamente a la entrada, sin los de su misión.
  /// Es lo que el formulario de la entrada puede editar.
  Future<List<Contact>> findOwnForJournalEntry(String entryId) async {
    _requireBatch(<String>{entryId});
    final List<TypedResult> rows =
        await (_database
                .select(_database.journalEntryContacts)
                .join(<Join<HasResultSet, dynamic>>[
                  innerJoin(
                    _database.contacts,
                    _database.contacts.id.equalsExp(
                      _database.journalEntryContacts.contactId,
                    ),
                  ),
                ])
              ..where(
                _database.journalEntryContacts.journalEntryId.equals(entryId),
              )
              ..orderBy(<OrderingTerm>[
                OrderingTerm.asc(_database.journalEntryContacts.createdAt),
                OrderingTerm.asc(_database.contacts.id),
              ]))
            .get();
    return rows
        .map((TypedResult row) => row.readTable(_database.contacts))
        .toList(growable: false);
  }

  /// Personajes de cada entrada: los suyos **más** los de su misión
  /// vinculada (ADR-006), sin repetir.
  Stream<Map<String, List<Contact>>> watchForJournalEntries(
    Set<String> entryIds,
  ) {
    if (entryIds.isEmpty) {
      return Stream<Map<String, List<Contact>>>.value(
        const <String, List<Contact>>{},
      );
    }
    _requireBatch(entryIds);
    final String placeholders = _placeholders(entryIds.length);
    final List<Variable<Object>> ids = entryIds
        .map((String id) => Variable<String>(id))
        .toList(growable: false);
    return _database
        .customSelect(
          '''
          SELECT links.owner_id AS owner_id, c.*
          FROM (
            SELECT owner_id, contact_id, MIN(linked_at) AS linked_at
            FROM (
              SELECT journal_entry_id AS owner_id, contact_id,
                     created_at AS linked_at
              FROM journal_entry_contacts
              WHERE journal_entry_id IN ($placeholders)
              UNION ALL
              SELECT je.id AS owner_id, mc.contact_id,
                     mc.created_at AS linked_at
              FROM journal_entries je
              INNER JOIN mission_contacts mc ON mc.mission_id = je.mission_id
              WHERE je.id IN ($placeholders)
            )
            GROUP BY owner_id, contact_id
          ) AS links
          INNER JOIN contacts c ON c.id = links.contact_id
          ORDER BY links.owner_id, links.linked_at, c.id
          ''',
          variables: <Variable<Object>>[...ids, ...ids],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.journalEntryContacts,
            _database.journalEntries,
            _database.missionContacts,
            _database.contacts,
          },
        )
        .watch()
        .map(_groupCustomRows);
  }

  /// Misiones donde aparece el personaje, de la más reciente a la más antigua
  /// según cuándo se vinculó.
  Stream<List<String>> watchMissionIdsForContact(String contactId) {
    return (_database.select(_database.missionContacts)
          ..where((table) => table.contactId.equals(contactId))
          ..orderBy(<OrderingTerm Function(MissionContacts)>[
            (table) => OrderingTerm.desc(table.createdAt),
            (table) => OrderingTerm.asc(table.missionId),
          ]))
        .watch()
        .map(
          (List<MissionContact> rows) => rows
              .map((MissionContact row) => row.missionId)
              .toList(growable: false),
        );
  }

  /// Entradas donde aparece el personaje, directamente o por su misión.
  Stream<List<String>> watchJournalEntryIdsForContact(String contactId) {
    return _database
        .customSelect(
          '''
          SELECT je.id AS entry_id
          FROM journal_entries je
          WHERE je.id IN (
              SELECT journal_entry_id FROM journal_entry_contacts
              WHERE contact_id = ?1
            )
            OR je.mission_id IN (
              SELECT mission_id FROM mission_contacts WHERE contact_id = ?1
            )
          ORDER BY je.occurred_at DESC, je.id DESC
          ''',
          variables: <Variable<Object>>[Variable<String>(contactId)],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.journalEntries,
            _database.journalEntryContacts,
            _database.missionContacts,
          },
        )
        .watch()
        .map(
          (List<QueryRow> rows) => rows
              .map((QueryRow row) => row.read<String>('entry_id'))
              .toList(growable: false),
        );
  }

  JoinedSelectStatement<HasResultSet, dynamic> _forMissionsQuery(
    Set<String> missionIds,
  ) {
    _requireBatch(missionIds);
    return _database
        .select(_database.missionContacts)
        .join(<Join<HasResultSet, dynamic>>[
          innerJoin(
            _database.contacts,
            _database.contacts.id.equalsExp(
              _database.missionContacts.contactId,
            ),
          ),
        ])
      ..where(_database.missionContacts.missionId.isIn(missionIds))
      ..orderBy(<OrderingTerm>[
        OrderingTerm.asc(_database.missionContacts.missionId),
        OrderingTerm.asc(_database.missionContacts.createdAt),
        OrderingTerm.asc(_database.contacts.id),
      ]);
  }

  Map<String, List<Contact>> _groupRows(List<TypedResult> rows) {
    final Map<String, List<Contact>> grouped = <String, List<Contact>>{};
    for (final TypedResult row in rows) {
      final String missionId = row
          .readTable(_database.missionContacts)
          .missionId;
      (grouped[missionId] ??= <Contact>[]).add(
        row.readTable(_database.contacts),
      );
    }
    return _unmodifiable(grouped);
  }

  Map<String, List<Contact>> _groupCustomRows(List<QueryRow> rows) {
    final Map<String, List<Contact>> grouped = <String, List<Contact>>{};
    for (final QueryRow row in rows) {
      final String ownerId = row.read<String>('owner_id');
      (grouped[ownerId] ??= <Contact>[]).add(_database.contacts.map(row.data));
    }
    return _unmodifiable(grouped);
  }

  Future<Contact> _writeWithRowVersion({
    required String contactId,
    required int expectedRowVersion,
    required ContactsCompanion changes,
  }) async {
    if (expectedRowVersion < 1) {
      throw ArgumentError.value(expectedRowVersion, 'expectedRowVersion');
    }
    final int affected =
        await (_database.update(_database.contacts)..where(
              (table) =>
                  table.id.equals(contactId) &
                  table.rowVersion.equals(expectedRowVersion),
            ))
            .write(
              changes.copyWith(rowVersion: Value<int>(expectedRowVersion + 1)),
            );
    if (affected != 1) {
      if (await findById(contactId) == null) {
        throw RecordNotFoundException(table: 'contacts', key: contactId);
      }
      throw OptimisticLockException(
        table: 'contacts',
        id: contactId,
        expectedRowVersion: expectedRowVersion,
      );
    }
    return _require(contactId);
  }

  Future<Contact> _require(String contactId) async {
    final Contact? contact = await findById(contactId);
    if (contact == null) {
      throw RecordNotFoundException(table: 'contacts', key: contactId);
    }
    return contact;
  }

  static bool _sameContent(Contact existing, ContactsCompanion incoming) =>
      existing.archivedAt == null &&
      existing.displayName ==
          (incoming.displayName.present ? incoming.displayName.value : null) &&
      existing.role == (incoming.role.present ? incoming.role.value : null) &&
      existing.description ==
          (incoming.description.present ? incoming.description.value : null);

  static void _requireBatch(Set<String> ids) {
    if (ids.length > maxBatchIds) {
      throw ArgumentError.value(
        ids.length,
        'ids',
        'At most $maxBatchIds ids per query.',
      );
    }
  }

  static String _placeholders(int count) =>
      List<String>.filled(count, '?').join(', ');

  static Map<String, List<Contact>> _unmodifiable(
    Map<String, List<Contact>> grouped,
  ) => Map<String, List<Contact>>.unmodifiable(
    grouped.map(
      (String key, List<Contact> value) => MapEntry<String, List<Contact>>(
        key,
        List<Contact>.unmodifiable(value),
      ),
    ),
  );

  static final List<OrderingTerm Function(Contacts)> _byName =
      <OrderingTerm Function(Contacts)>[
        (table) => OrderingTerm.asc(table.displayName.isNull()),
        (table) => OrderingTerm.asc(table.displayName.collate(Collate.noCase)),
        (table) => OrderingTerm.asc(table.createdAt),
        (table) => OrderingTerm.asc(table.id),
      ];
}
