import 'package:drift/drift.dart';

import 'default_seed_v1.dart';

part 'app_database.g.dart';

typedef UtcNowMilliseconds = int Function();

@DriftDatabase(include: {'schema.drift'})
final class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor, {UtcNowMilliseconds? utcNowMilliseconds})
    : _utcNowMilliseconds = utcNowMilliseconds ?? _systemUtcNowMilliseconds;

  final UtcNowMilliseconds _utcNowMilliseconds;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await migrator.createAll();
      await insertDefaultSeedV1(this, nowUtcMs: _utcNowMilliseconds());
    },
    onUpgrade: (Migrator migrator, int from, int to) {
      throw UnsupportedError(
        'No schema upgrade exists for v1 (requested $from -> $to).',
      );
    },
    beforeOpen: (OpeningDetails _) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await insertDefaultSeedV1(this, nowUtcMs: _utcNowMilliseconds());
      await _verifyConnectionIntegrity();
    },
  );

  Future<void> _verifyConnectionIntegrity() async {
    final foreignKeyViolations = await customSelect(
      'PRAGMA foreign_key_check',
    ).get();
    if (foreignKeyViolations.isNotEmpty) {
      throw StateError(
        'Database v1 failed foreign_key_check '
        '(${foreignKeyViolations.length} violation(s)).',
      );
    }

    final integrityRows = await customSelect('PRAGMA integrity_check').get();
    final integrityIsValid =
        integrityRows.length == 1 &&
        integrityRows.single.data.values.single == 'ok';
    if (!integrityIsValid) {
      throw StateError('Database v1 failed integrity_check.');
    }
  }

  static int _systemUtcNowMilliseconds() =>
      DateTime.now().toUtc().millisecondsSinceEpoch;
}
