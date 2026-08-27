import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../infrastructure/database/app_database.dart' as drift;
import '../../../infrastructure/database/daos/journal_dao.dart';
import '../domain/models/journal_entry.dart';
import '../domain/models/journal_photo.dart';
import '../domain/repositories/journal_repository.dart';
import 'journal_mapper.dart';

final class DriftJournalRepository implements JournalRepository {
  const DriftJournalRepository(this._dao);

  final JournalDao _dao;

  @override
  Future<Result<JournalEntry>> create(JournalEntry entry) async {
    final AppFailure? failure = _validateEntry(entry);
    if (failure != null) {
      return Failure<JournalEntry>(failure);
    }
    try {
      final aggregate = await _dao.insertAggregate(
        entry: JournalMapper.toInsert(entry),
      );
      return Success<JournalEntry>(
        JournalMapper.fromDrift(
          aggregate.entry,
          attachmentCount: aggregate.attachments.length,
        ),
      );
    } on Object catch (error) {
      return Failure<JournalEntry>(
        StorageFailure('No se pudo crear la entrada.', cause: error),
      );
    }
  }

  @override
  Future<Result<JournalEntry?>> findById(String id) async {
    if (id.trim().isEmpty) {
      return const Failure<JournalEntry?>(
        ValidationFailure('El identificador de Bitácora es obligatorio.'),
      );
    }

    try {
      final aggregate = await _dao.findAggregate(id);
      return Success<JournalEntry?>(
        aggregate == null
            ? null
            : JournalMapper.fromDrift(
                aggregate.entry,
                attachmentCount: aggregate.attachments.length,
              ),
      );
    } on Object catch (error) {
      return Failure<JournalEntry?>(
        StorageFailure('No se pudo leer la entrada.', cause: error),
      );
    }
  }

  @override
  Future<Result<List<JournalEntry>>> findRecent({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 100,
  }) async {
    if (!startUtc.isUtc ||
        !endUtc.isUtc ||
        !endUtc.isAfter(startUtc) ||
        limit <= 0) {
      return const Failure<List<JournalEntry>>(
        ValidationFailure(
          'El período de Bitácora y su límite deben ser válidos.',
        ),
      );
    }

    return watchRecent(startUtc: startUtc, endUtc: endUtc, limit: limit).first;
  }

  @override
  Future<Result<JournalEntry>> update(JournalEntry entry) async {
    final AppFailure? failure = _validateEntry(entry);
    if (failure != null) {
      return Failure<JournalEntry>(failure);
    }
    try {
      final updated = await _dao.updateEntry(
        entryId: entry.id,
        changes: JournalMapper.toUpdate(entry),
      );
      return Success<JournalEntry>(
        JournalMapper.fromDrift(
          updated,
          attachmentCount: entry.attachmentCount,
        ),
      );
    } on Object catch (error) {
      return Failure<JournalEntry>(
        StorageFailure('No se pudo actualizar la entrada.', cause: error),
      );
    }
  }

  @override
  Future<Result<JournalEntry>> archiveEntry({
    required String entryId,
    required DateTime archivedAtUtc,
    required DateTime updatedAtUtc,
  }) async {
    if (entryId.trim().isEmpty || !archivedAtUtc.isUtc || !updatedAtUtc.isUtc) {
      return const Failure<JournalEntry>(
        ValidationFailure('La entrada no es válida para archivar.'),
      );
    }
    try {
      final row = await _dao.archiveEntry(
        entryId: entryId,
        archivedAtUtcMs: archivedAtUtc.millisecondsSinceEpoch,
        updatedAtUtcMs: updatedAtUtc.millisecondsSinceEpoch,
      );
      return Success<JournalEntry>(await _mapRow(row));
    } on Object catch (error) {
      return Failure<JournalEntry>(
        StorageFailure('No se pudo archivar la entrada.', cause: error),
      );
    }
  }

  @override
  Future<Result<JournalEntry>> restoreEntry({
    required String entryId,
    required DateTime updatedAtUtc,
  }) async {
    if (entryId.trim().isEmpty || !updatedAtUtc.isUtc) {
      return const Failure<JournalEntry>(
        ValidationFailure('La entrada no es válida para restaurar.'),
      );
    }
    try {
      final row = await _dao.restoreEntry(
        entryId: entryId,
        updatedAtUtcMs: updatedAtUtc.millisecondsSinceEpoch,
      );
      return Success<JournalEntry>(await _mapRow(row));
    } on Object catch (error) {
      return Failure<JournalEntry>(
        StorageFailure('No se pudo restaurar la entrada.', cause: error),
      );
    }
  }

  @override
  Future<Result<List<JournalEntry>>> search(
    JournalSearchCriteria criteria,
  ) async {
    if (!criteria.startUtc.isUtc ||
        !criteria.endUtc.isUtc ||
        !criteria.endUtc.isAfter(criteria.startUtc) ||
        criteria.query.trim().length > 160 ||
        criteria.limit <= 0) {
      return const Failure<List<JournalEntry>>(
        ValidationFailure('Los filtros de búsqueda no son válidos.'),
      );
    }
    try {
      final rows = await _dao
          .watchTimeline(
            startUtcMs: criteria.startUtc.millisecondsSinceEpoch,
            endUtcMs: criteria.endUtc.millisecondsSinceEpoch,
            originTypes: criteria.origins.map(_originToDrift).toSet(),
            searchText: criteria.query,
            withAttachmentsOnly: criteria.withPhotosOnly,
            limit: criteria.limit,
          )
          .first;
      return Success<List<JournalEntry>>(await _mapRows(rows));
    } on Object catch (error) {
      return Failure<List<JournalEntry>>(
        StorageFailure('No se pudo buscar en la Bitácora.', cause: error),
      );
    }
  }

  @override
  Future<Result<JournalPhoto>> addPhoto(JournalPhoto photo) async {
    final AppFailure? failure = _validatePhoto(photo);
    if (failure != null) {
      return Failure<JournalPhoto>(failure);
    }
    try {
      final row = await _dao.addAttachment(
        drift.JournalAttachmentsCompanion.insert(
          id: photo.id,
          journalEntryId: photo.journalEntryId,
          kind: 'PHOTO',
          storageName: photo.storageName,
          mimeType: photo.mimeType,
          byteLength: photo.byteLength,
          cipherSha256: photo.cipherSha256,
          widthPx: photo.widthPx,
          heightPx: photo.heightPx,
          position: photo.position,
          createdAt: photo.createdAtUtc.millisecondsSinceEpoch,
        ),
      );
      return Success<JournalPhoto>(_photoFromDrift(row));
    } on Object catch (error) {
      return Failure<JournalPhoto>(
        StorageFailure('No se pudo registrar la fotografía.', cause: error),
      );
    }
  }

  @override
  Future<Result<JournalPhoto?>> archivePhoto({
    required String attachmentId,
    required DateTime archivedAtUtc,
  }) async {
    if (attachmentId.trim().isEmpty || !archivedAtUtc.isUtc) {
      return const Failure<JournalPhoto?>(
        ValidationFailure('La fotografía no es válida.'),
      );
    }
    try {
      final row = await _dao.archiveAttachment(
        attachmentId: attachmentId,
        archivedAtUtcMs: archivedAtUtc.millisecondsSinceEpoch,
      );
      return Success<JournalPhoto?>(row == null ? null : _photoFromDrift(row));
    } on Object catch (error) {
      return Failure<JournalPhoto?>(
        StorageFailure('No se pudo retirar la fotografía.', cause: error),
      );
    }
  }

  @override
  Future<Result<List<JournalPhoto>>> findPhotos(String entryId) async {
    if (entryId.trim().isEmpty) {
      return const Failure<List<JournalPhoto>>(
        ValidationFailure('La entrada de Bitácora no es válida.'),
      );
    }
    try {
      final rows = await _dao.findActiveAttachments(entryId);
      return Success<List<JournalPhoto>>(
        rows.map(_photoFromDrift).toList(growable: false),
      );
    } on Object catch (error) {
      return Failure<List<JournalPhoto>>(
        StorageFailure('No se pudieron leer las fotografías.', cause: error),
      );
    }
  }

  @override
  Future<Result<Set<String>>> findActivePhotoStorageNames() async {
    try {
      return Success<Set<String>>(
        (await _dao.findActiveAttachmentStorageNames()).toSet(),
      );
    } on Object catch (error) {
      return Failure<Set<String>>(
        StorageFailure(
          'No se pudo verificar el almacén privado.',
          cause: error,
        ),
      );
    }
  }

  @override
  Stream<Result<List<JournalEntry>>> watchRecent({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 100,
  }) async* {
    if (!startUtc.isUtc ||
        !endUtc.isUtc ||
        !endUtc.isAfter(startUtc) ||
        limit <= 0) {
      yield const Failure<List<JournalEntry>>(
        ValidationFailure(
          'El período de Bitácora y su límite deben ser válidos.',
        ),
      );
      return;
    }

    try {
      await for (final rows in _dao.watchTimeline(
        startUtcMs: startUtc.millisecondsSinceEpoch,
        endUtcMs: endUtc.millisecondsSinceEpoch,
        limit: limit,
      )) {
        yield Success<List<JournalEntry>>(await _mapRows(rows));
      }
    } on Object catch (error) {
      yield Failure<List<JournalEntry>>(
        StorageFailure(
          'No se pudo leer la cronología de Bitácora.',
          cause: error,
        ),
      );
    }
  }

  @override
  Stream<Result<List<JournalEntry>>> watchArchived({int limit = 200}) async* {
    if (limit <= 0) {
      yield const Failure<List<JournalEntry>>(
        ValidationFailure('El límite del archivo no es válido.'),
      );
      return;
    }
    try {
      await for (final rows in _dao.watchArchived(limit: limit)) {
        yield Success<List<JournalEntry>>(await _mapRows(rows));
      }
    } on Object catch (error) {
      yield Failure<List<JournalEntry>>(
        StorageFailure('No se pudo leer el archivo de Bitácora.', cause: error),
      );
    }
  }

  Future<List<JournalEntry>> _mapRows(Iterable<drift.JournalEntry> rows) async {
    final mapped = await Future.wait<JournalEntry?>(
      rows.map((row) async {
        final aggregate = await _dao.findAggregate(row.id);
        return aggregate == null
            ? null
            : JournalMapper.fromDrift(
                aggregate.entry,
                attachmentCount: aggregate.attachments.length,
              );
      }),
    );
    return mapped.nonNulls.toList(growable: false);
  }

  Future<JournalEntry> _mapRow(drift.JournalEntry row) async {
    final aggregate = await _dao.findAggregate(row.id);
    return JournalMapper.fromDrift(
      row,
      attachmentCount: aggregate?.attachments.length ?? 0,
    );
  }

  AppFailure? _validateEntry(JournalEntry entry) {
    if (entry.id.trim().isEmpty ||
        entry.title.trim().isEmpty ||
        entry.title.trim().length > 160 ||
        !entry.occurredAtUtc.isUtc ||
        !entry.createdAtUtc.isUtc ||
        !entry.updatedAtUtc.isUtc) {
      return const ValidationFailure('La entrada contiene valores inválidos.');
    }
    return null;
  }

  AppFailure? _validatePhoto(JournalPhoto photo) {
    if (photo.id.trim().isEmpty ||
        photo.journalEntryId.trim().isEmpty ||
        photo.storageName.trim().isEmpty ||
        photo.mimeType != 'image/jpeg' ||
        photo.byteLength <= 0 ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(photo.cipherSha256) ||
        photo.widthPx <= 0 ||
        photo.heightPx <= 0 ||
        photo.position < 0 ||
        !photo.createdAtUtc.isUtc) {
      return const ValidationFailure(
        'La fotografía contiene valores inválidos.',
      );
    }
    return null;
  }

  static JournalPhoto _photoFromDrift(drift.JournalAttachment row) =>
      JournalPhoto(
        id: row.id,
        journalEntryId: row.journalEntryId,
        storageName: row.storageName,
        mimeType: row.mimeType,
        byteLength: row.byteLength,
        cipherSha256: row.cipherSha256,
        widthPx: row.widthPx,
        heightPx: row.heightPx,
        position: row.position,
        createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
          row.createdAt,
          isUtc: true,
        ),
      );

  static String _originToDrift(JournalOrigin origin) => switch (origin) {
    JournalOrigin.manual => 'MANUAL',
    JournalOrigin.mission => 'MISSION',
    JournalOrigin.transaction => 'TRANSACTION',
    JournalOrigin.system => 'SYSTEM',
  };
}
