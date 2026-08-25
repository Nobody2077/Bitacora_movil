import 'package:drift/drift.dart';

import '../app_database.dart';
import 'dao_support.dart';

final class JournalEntryAggregate {
  const JournalEntryAggregate({required this.entry, required this.attachments});

  final JournalEntry entry;
  final List<JournalAttachment> attachments;
}

final class JournalDao {
  JournalDao(this._database);

  final AppDatabase _database;

  Future<JournalEntryAggregate?> findAggregate(String entryId) {
    return _database.transaction(() => _findAggregate(entryId));
  }

  Future<JournalEntryAggregate?> _findAggregate(String entryId) async {
    final entry = await (_database.select(
      _database.journalEntries,
    )..where((table) => table.id.equals(entryId))).getSingleOrNull();
    if (entry == null) {
      return null;
    }
    final attachments =
        await (_database.select(_database.journalAttachments)
              ..where(
                (table) =>
                    table.journalEntryId.equals(entryId) &
                    table.archivedAt.isNull(),
              )
              ..orderBy(<OrderingTerm Function(JournalAttachments)>[
                (table) => OrderingTerm.asc(table.position),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    return JournalEntryAggregate(entry: entry, attachments: attachments);
  }

  Stream<List<JournalEntry>> watchTimeline({
    required int startUtcMs,
    required int endUtcMs,
    Set<String> originTypes = const <String>{},
    String? searchText,
    int limit = 100,
    int offset = 0,
  }) {
    if (endUtcMs <= startUtcMs) {
      throw ArgumentError.value(
        endUtcMs,
        'endUtcMs',
        'Must exceed startUtcMs.',
      );
    }
    if (limit <= 0 || offset < 0) {
      throw ArgumentError('Pagination values are invalid.');
    }

    final normalizedSearch = searchText?.trim();
    final query = _database.select(_database.journalEntries)
      ..where((table) {
        var predicate =
            table.occurredAt.isBiggerOrEqualValue(startUtcMs) &
            table.occurredAt.isSmallerThanValue(endUtcMs) &
            table.archivedAt.isNull();
        if (originTypes.isNotEmpty) {
          predicate = predicate & table.originType.isIn(originTypes);
        }
        if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
          final pattern = '%$normalizedSearch%';
          predicate =
              predicate &
              (table.title.like(pattern) | table.body.like(pattern));
        }
        return predicate;
      })
      ..orderBy(<OrderingTerm Function(JournalEntries)>[
        (table) => OrderingTerm.desc(table.occurredAt),
        (table) => OrderingTerm.desc(table.id),
      ])
      ..limit(limit, offset: offset);
    return query.watch();
  }

  Future<JournalEntryAggregate> insertAggregate({
    required JournalEntriesCompanion entry,
    Iterable<JournalAttachmentsCompanion> attachments =
        const <JournalAttachmentsCompanion>[],
  }) {
    if (!entry.id.present) {
      throw ArgumentError('Journal entry id must be present.');
    }
    final entryId = entry.id.value;

    return _database.transaction(() async {
      await _validateOriginForInsert(entry);
      await _database.into(_database.journalEntries).insert(entry);
      for (final attachment in attachments) {
        _requireEntryId(attachment.journalEntryId, entryId);
        await _database.into(_database.journalAttachments).insert(attachment);
      }
      final inserted = await _findAggregate(entryId);
      if (inserted == null) {
        throw RecordNotFoundException(table: 'journal_entries', key: entryId);
      }
      return inserted;
    });
  }

  Future<JournalAttachment> addAttachment(
    JournalAttachmentsCompanion attachment,
  ) {
    return _database
        .into(_database.journalAttachments)
        .insertReturning(attachment);
  }

  Future<JournalEntry> updateEntry({
    required String entryId,
    required JournalEntriesCompanion changes,
  }) {
    if (changes.id.present) {
      throw ArgumentError('Journal entry id cannot be changed.');
    }
    return _database.transaction(() async {
      final current = await (_database.select(
        _database.journalEntries,
      )..where((table) => table.id.equals(entryId))).getSingleOrNull();
      if (current == null) {
        throw RecordNotFoundException(table: 'journal_entries', key: entryId);
      }
      await _validateOriginForUpdate(current, changes);

      final affected = await (_database.update(
        _database.journalEntries,
      )..where((table) => table.id.equals(entryId))).write(changes);
      if (affected != 1) {
        throw RecordNotFoundException(table: 'journal_entries', key: entryId);
      }
      return (_database.select(
        _database.journalEntries,
      )..where((table) => table.id.equals(entryId))).getSingle();
    });
  }

  Future<JournalEntry> archiveEntry({
    required String entryId,
    required int archivedAtUtcMs,
    required int updatedAtUtcMs,
  }) {
    return updateEntry(
      entryId: entryId,
      changes: JournalEntriesCompanion(
        archivedAt: Value<int?>(archivedAtUtcMs),
        updatedAt: Value<int>(updatedAtUtcMs),
      ),
    );
  }

  Future<int> archiveAttachment({
    required String attachmentId,
    required int archivedAtUtcMs,
  }) {
    return (_database.update(
      _database.journalAttachments,
    )..where((table) => table.id.equals(attachmentId))).write(
      JournalAttachmentsCompanion(archivedAt: Value<int?>(archivedAtUtcMs)),
    );
  }

  Future<List<JournalEntry>> findByMission(String missionId) {
    return (_database.select(_database.journalEntries)
          ..where((table) => table.missionId.equals(missionId))
          ..orderBy(<OrderingTerm Function(JournalEntries)>[
            (table) => OrderingTerm.desc(table.occurredAt),
          ]))
        .get();
  }

  void _requireEntryId(Value<String> actual, String expected) {
    if (!actual.present || actual.value != expected) {
      throw ArgumentError('Attachment must reference journal entry $expected.');
    }
  }

  Future<void> _validateOriginForInsert(JournalEntriesCompanion entry) async {
    if (!entry.originType.present) {
      throw ArgumentError('Journal origin_type must be present.');
    }
    await _validateOriginReference(
      originType: entry.originType.value,
      missionId: entry.missionId.present ? entry.missionId.value : null,
      transactionId: entry.transactionId.present
          ? entry.transactionId.value
          : null,
    );
  }

  Future<void> _validateOriginForUpdate(
    JournalEntry current,
    JournalEntriesCompanion changes,
  ) {
    if (!changes.originType.present &&
        !changes.missionId.present &&
        !changes.transactionId.present) {
      return Future<void>.value();
    }
    return _validateOriginReference(
      originType: changes.originType.present
          ? changes.originType.value
          : current.originType,
      missionId: changes.missionId.present
          ? changes.missionId.value
          : current.missionId,
      transactionId: changes.transactionId.present
          ? changes.transactionId.value
          : current.transactionId,
    );
  }

  Future<void> _validateOriginReference({
    required String originType,
    required String? missionId,
    required String? transactionId,
  }) async {
    if (originType == 'MISSION') {
      if (missionId == null) {
        throw const DatabaseInvariantException(
          'MISSION journal origin requires mission_id.',
        );
      }
      final source =
          await (_database.selectOnly(_database.missions)
                ..addColumns(<Expression<Object>>[_database.missions.id])
                ..where(_database.missions.id.equals(missionId)))
              .getSingleOrNull();
      if (source == null) {
        throw RecordNotFoundException(table: 'missions', key: missionId);
      }
    } else if (originType == 'TRANSACTION') {
      if (transactionId == null) {
        throw const DatabaseInvariantException(
          'TRANSACTION journal origin requires transaction_id.',
        );
      }
      final source =
          await (_database.selectOnly(_database.transactions)
                ..addColumns(<Expression<Object>>[_database.transactions.id])
                ..where(_database.transactions.id.equals(transactionId)))
              .getSingleOrNull();
      if (source == null) {
        throw RecordNotFoundException(
          table: 'transactions',
          key: transactionId,
        );
      }
    }
  }
}
