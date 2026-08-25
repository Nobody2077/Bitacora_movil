import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../infrastructure/database/daos/journal_dao.dart';
import '../domain/models/journal_entry.dart';
import '../domain/repositories/journal_repository.dart';
import 'journal_mapper.dart';

final class DriftJournalRepository implements JournalRepository {
  const DriftJournalRepository(this._dao);

  final JournalDao _dao;

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

    try {
      final rows = await _dao
          .watchTimeline(
            startUtcMs: startUtc.millisecondsSinceEpoch,
            endUtcMs: endUtc.millisecondsSinceEpoch,
            limit: limit,
          )
          .first;
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
      return Success<List<JournalEntry>>(
        mapped.nonNulls.toList(growable: false),
      );
    } on Object catch (error) {
      return Failure<List<JournalEntry>>(
        StorageFailure(
          'No se pudo leer la cronología de Bitácora.',
          cause: error,
        ),
      );
    }
  }
}
