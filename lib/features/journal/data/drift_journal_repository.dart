import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../infrastructure/database/app_database.dart' as drift;
import '../../../infrastructure/database/daos/journal_dao.dart';
import '../domain/models/journal_entry.dart';
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
}
