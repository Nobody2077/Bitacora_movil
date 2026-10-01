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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await migrator.createAll();
      await insertDefaultSeedV1(this, nowUtcMs: _utcNowMilliseconds());
      await _syncSchemaVersionMirror();
    },
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from < 1 || to != 4 || from >= to) {
        throw UnsupportedError('No schema upgrade exists for $from -> $to.');
      }
      if (from == 1) {
        await migrator.addColumn(journalEntries, journalEntries.moodDetail);
      }
      if (from <= 2) {
        await migrator.addColumn(
          missionTemplates,
          missionTemplates.availabilityMode,
        );
      }
      if (from <= 3) {
        // ADR-006: solo añade. Ninguna tabla existente se reescribe.
        await migrator.addColumn(missions, missions.location);
        await migrator.addColumn(missionTemplates, missionTemplates.location);
        for (final DatabaseSchemaEntity entity in allSchemaEntities) {
          if (_schemaV4Entities.contains(entity.entityName)) {
            await migrator.create(entity);
          }
        }
      }
      await _syncSchemaVersionMirror();
    },
    beforeOpen: (OpeningDetails _) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await insertDefaultSeedV1(this, nowUtcMs: _utcNowMilliseconds());
      await _syncSchemaVersionMirror();
      await _verifyConnectionIntegrity();
    },
  );

  /// Tablas e índices nuevos de v4 (ADR-006), en el orden de `schema.drift`,
  /// que respeta las claves foráneas: cada tabla antes de sus índices y de
  /// las tablas que la referencian.
  static const Set<String> _schemaV4Entities = <String>{
    'contacts',
    'contact_photos',
    'uq_contact_photo_current',
    'mission_contacts',
    'idx_mission_contacts_contact',
    'journal_entry_contacts',
    'idx_journal_contacts_contact',
    'mission_photos',
    'uq_mission_photo_current',
    'inventory_items',
    'idx_items_status_category',
    'idx_items_equipped_zone',
    'idx_items_parent',
    'item_photos',
    'uq_item_photo_current',
    'projects',
    'project_items',
    'idx_project_items_item',
    'idx_project_items_contact',
    'craft_operations',
    'uq_craft_mission_grant',
    'craft_component_ledger',
    'idx_craft_ledger_rarity',
    'reward_specs',
    'reward_spec_costs',
    'reward_vouchers',
    'idx_vouchers_status',
  };

  Future<void> _syncSchemaVersionMirror() => customStatement(
    '''
      UPDATE schema_metadata
      SET value = ?, updated_at = ?
      WHERE "key" = 'schema_version' AND value <> ?
    ''',
    <Object?>[
      schemaVersion.toString(),
      _utcNowMilliseconds(),
      schemaVersion.toString(),
    ],
  );

  Future<void> _verifyConnectionIntegrity() async {
    final foreignKeyViolations = await customSelect(
      'PRAGMA foreign_key_check',
    ).get();
    if (foreignKeyViolations.isNotEmpty) {
      throw StateError(
        'Database failed foreign_key_check '
        '(${foreignKeyViolations.length} violation(s)).',
      );
    }

    final integrityRows = await customSelect('PRAGMA integrity_check').get();
    final integrityIsValid =
        integrityRows.length == 1 &&
        integrityRows.single.data.values.single == 'ok';
    if (!integrityIsValid) {
      throw StateError('Database failed integrity_check.');
    }
  }

  static int _systemUtcNowMilliseconds() =>
      DateTime.now().toUtc().millisecondsSinceEpoch;
}
