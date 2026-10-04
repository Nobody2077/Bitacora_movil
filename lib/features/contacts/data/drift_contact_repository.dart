import 'package:drift/drift.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../infrastructure/database/app_database.dart' as drift;
import '../../../infrastructure/database/daos/contact_dao.dart';
import '../../../infrastructure/database/daos/dao_support.dart';
import '../domain/models/contact.dart';
import '../domain/repositories/contact_repository.dart';

final class DriftContactRepository implements ContactRepository {
  const DriftContactRepository(this._dao);

  final ContactDao _dao;

  @override
  Stream<Result<List<Contact>>> watchActive() =>
      _watchList(_dao.watchActive(), 'No se pudieron leer los personajes.');

  @override
  Stream<Result<List<Contact>>> watchArchived() => _watchList(
    _dao.watchArchived(),
    'No se pudieron leer los personajes archivados.',
  );

  @override
  Future<Result<Contact?>> findById(String id) async {
    if (id.trim().isEmpty) {
      return const Failure<Contact?>(
        ValidationFailure('El identificador del personaje es obligatorio.'),
      );
    }
    try {
      final drift.Contact? row = await _dao.findById(id);
      return Success<Contact?>(row == null ? null : fromDrift(row));
    } on Object catch (error) {
      return Failure<Contact?>(
        StorageFailure('No se pudo leer el personaje.', cause: error),
      );
    }
  }

  @override
  Stream<Result<Contact?>> watchById(String id) async* {
    if (id.trim().isEmpty) {
      yield const Failure<Contact?>(
        ValidationFailure('El identificador del personaje es obligatorio.'),
      );
      return;
    }
    try {
      await for (final drift.Contact? row in _dao.watchById(id)) {
        yield Success<Contact?>(row == null ? null : fromDrift(row));
      }
    } on Object catch (error) {
      yield Failure<Contact?>(
        StorageFailure('No se pudo leer el personaje.', cause: error),
      );
    }
  }

  @override
  Future<Result<Contact>> create(Contact contact) async {
    final ValidationFailure? invalid = _validate(contact);
    if (invalid != null) {
      return Failure<Contact>(invalid);
    }
    try {
      final DaoWriteResult<drift.Contact> written = await _dao.insertContact(
        drift.ContactsCompanion.insert(
          id: contact.id,
          displayName: Value<String?>(contact.displayName),
          role: Value<String?>(contact.role),
          description: Value<String?>(contact.description),
          createdAt: contact.createdAtUtc.millisecondsSinceEpoch,
          updatedAt: contact.updatedAtUtc.millisecondsSinceEpoch,
        ),
      );
      return Success<Contact>(fromDrift(written.value));
    } on IdempotencyConflictException {
      return const Failure<Contact>(
        ConflictFailure('Ya existe otro personaje con ese identificador.'),
      );
    } on Object catch (error) {
      return Failure<Contact>(
        StorageFailure('No se pudo crear el personaje.', cause: error),
      );
    }
  }

  @override
  Future<Result<Contact>> update(Contact contact) async {
    final ValidationFailure? invalid = _validate(contact);
    if (invalid != null) {
      return Failure<Contact>(invalid);
    }
    return _write(
      () => _dao.updateContact(
        contactId: contact.id,
        expectedRowVersion: contact.rowVersion,
        changes: drift.ContactsCompanion(
          displayName: Value<String?>(contact.displayName),
          role: Value<String?>(contact.role),
          description: Value<String?>(contact.description),
          updatedAt: Value<int>(contact.updatedAtUtc.millisecondsSinceEpoch),
        ),
      ),
      'No se pudo guardar el personaje.',
    );
  }

  @override
  Future<Result<Contact>> archive(
    Contact contact, {
    required DateTime atUtc,
  }) async {
    if (!atUtc.isUtc) {
      return const Failure<Contact>(
        ValidationFailure('El instante de archivo no es válido.'),
      );
    }
    return _write(
      () => _dao.archiveContact(
        contactId: contact.id,
        expectedRowVersion: contact.rowVersion,
        archivedAtUtcMs: atUtc.millisecondsSinceEpoch,
      ),
      'No se pudo archivar el personaje.',
    );
  }

  @override
  Future<Result<Contact>> restore(
    Contact contact, {
    required DateTime atUtc,
  }) async {
    if (!atUtc.isUtc) {
      return const Failure<Contact>(
        ValidationFailure('El instante de restauración no es válido.'),
      );
    }
    return _write(
      () => _dao.restoreContact(
        contactId: contact.id,
        expectedRowVersion: contact.rowVersion,
        updatedAtUtcMs: atUtc.millisecondsSinceEpoch,
      ),
      'No se pudo restaurar el personaje.',
    );
  }

  @override
  Future<Result<List<Contact>>> findForMission(String missionId) => _readList(
    () => _dao.findForMission(missionId),
    'No se pudieron leer los personajes de la misión.',
  );

  @override
  Future<Result<List<Contact>>> findOwnForJournalEntry(String entryId) =>
      _readList(
        () => _dao.findOwnForJournalEntry(entryId),
        'No se pudieron leer los personajes de la entrada.',
      );

  @override
  Stream<Result<Map<String, List<Contact>>>> watchForMissions(
    Set<String> missionIds,
  ) => _watchGrouped(
    () => _dao.watchForMissions(missionIds),
    'No se pudieron leer los personajes de las misiones.',
  );

  @override
  Stream<Result<Map<String, List<Contact>>>> watchForJournalEntries(
    Set<String> entryIds,
  ) => _watchGrouped(
    () => _dao.watchForJournalEntries(entryIds),
    'No se pudieron leer los personajes de las entradas.',
  );

  @override
  Stream<Result<List<String>>> watchMissionIdsForContact(String contactId) =>
      _watchIds(
        () => _dao.watchMissionIdsForContact(contactId),
        'No se pudieron leer las misiones del personaje.',
      );

  @override
  Stream<Result<List<String>>> watchJournalEntryIdsForContact(
    String contactId,
  ) => _watchIds(
    () => _dao.watchJournalEntryIdsForContact(contactId),
    'No se pudieron leer las entradas del personaje.',
  );

  static Contact fromDrift(drift.Contact row) => Contact(
    id: row.id,
    displayName: row.displayName,
    role: row.role,
    description: row.description,
    createdAtUtc: _utc(row.createdAt),
    updatedAtUtc: _utc(row.updatedAt),
    archivedAtUtc: row.archivedAt == null ? null : _utc(row.archivedAt!),
    rowVersion: row.rowVersion,
  );

  Future<Result<Contact>> _write(
    Future<drift.Contact> Function() action,
    String failureMessage,
  ) async {
    try {
      return Success<Contact>(fromDrift(await action()));
    } on OptimisticLockException {
      return const Failure<Contact>(
        ConflictFailure(
          'El personaje cambió en otro lugar. Vuelve a abrirlo antes de guardar.',
        ),
      );
    } on RecordNotFoundException {
      return const Failure<Contact>(
        ConflictFailure('El personaje ya no está disponible.'),
      );
    } on DatabaseInvariantException {
      return const Failure<Contact>(
        ConflictFailure('El personaje ya estaba en ese estado.'),
      );
    } on Object catch (error) {
      return Failure<Contact>(StorageFailure(failureMessage, cause: error));
    }
  }

  static Future<Result<List<Contact>>> _readList(
    Future<List<drift.Contact>> Function() read,
    String failureMessage,
  ) async {
    try {
      return Success<List<Contact>>(
        (await read()).map(fromDrift).toList(growable: false),
      );
    } on Object catch (error) {
      return Failure<List<Contact>>(
        StorageFailure(failureMessage, cause: error),
      );
    }
  }

  static Stream<Result<List<Contact>>> _watchList(
    Stream<List<drift.Contact>> rows,
    String failureMessage,
  ) async* {
    try {
      await for (final List<drift.Contact> batch in rows) {
        yield Success<List<Contact>>(
          batch.map(fromDrift).toList(growable: false),
        );
      }
    } on Object catch (error) {
      yield Failure<List<Contact>>(
        StorageFailure(failureMessage, cause: error),
      );
    }
  }

  static Stream<Result<Map<String, List<Contact>>>> _watchGrouped(
    Stream<Map<String, List<drift.Contact>>> Function() open,
    String failureMessage,
  ) async* {
    try {
      await for (final Map<String, List<drift.Contact>> grouped in open()) {
        yield Success<Map<String, List<Contact>>>(
          Map<String, List<Contact>>.unmodifiable(
            grouped.map(
              (String key, List<drift.Contact> rows) =>
                  MapEntry<String, List<Contact>>(
                    key,
                    rows.map(fromDrift).toList(growable: false),
                  ),
            ),
          ),
        );
      }
    } on Object catch (error) {
      yield Failure<Map<String, List<Contact>>>(
        StorageFailure(failureMessage, cause: error),
      );
    }
  }

  static Stream<Result<List<String>>> _watchIds(
    Stream<List<String>> Function() open,
    String failureMessage,
  ) async* {
    try {
      await for (final List<String> ids in open()) {
        yield Success<List<String>>(ids);
      }
    } on Object catch (error) {
      yield Failure<List<String>>(StorageFailure(failureMessage, cause: error));
    }
  }

  static ValidationFailure? _validate(Contact contact) {
    if (contact.id.trim().isEmpty ||
        !contact.createdAtUtc.isUtc ||
        !contact.updatedAtUtc.isUtc ||
        contact.rowVersion < 1 ||
        !_validOptional(contact.displayName, Contact.maxDisplayNameLength) ||
        !_validOptional(contact.role, Contact.maxRoleLength) ||
        (contact.description != null &&
            contact.description!.length > Contact.maxDescriptionLength)) {
      return const ValidationFailure(
        'El personaje contiene valores inválidos.',
      );
    }
    return null;
  }

  static bool _validOptional(String? value, int maxLength) {
    if (value == null) {
      return true;
    }
    final int length = value.trim().length;
    return length >= 1 && length <= maxLength;
  }

  static DateTime _utc(int milliseconds) =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
}
