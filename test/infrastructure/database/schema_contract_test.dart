import 'dart:io';

import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const int _seedTime = 1787521320000;

const Set<String> _expectedTables = <String>{
  'life_areas',
  'mission_templates',
  'mission_template_objectives',
  'recurrence_rules',
  'missions',
  'mission_objectives',
  'time_entries',
  'mission_events',
  'notification_schedules',
  'transactions',
  'savings_goals',
  'goal_allocations',
  'journal_entries',
  'journal_attachments',
  'xp_transactions',
  'title_definitions',
  'title_history',
  'app_settings',
  'schema_metadata',
};

const Map<String, _IndexContract> _expectedIndexes = <String, _IndexContract>{
  'uq_life_areas_active_name': _IndexContract(
    table: 'life_areas',
    columns: <String>['name'],
    unique: true,
    partial: true,
  ),
  'uq_life_areas_default_active': _IndexContract(
    table: 'life_areas',
    columns: <String>['is_default'],
    unique: true,
    partial: true,
  ),
  'uq_occurrence': _IndexContract(
    table: 'missions',
    columns: <String>['template_id', 'scheduled_at'],
    unique: true,
    partial: true,
  ),
  'idx_missions_status_date': _IndexContract(
    table: 'missions',
    columns: <String>['status', 'scheduled_at'],
  ),
  'idx_missions_area_date': _IndexContract(
    table: 'missions',
    columns: <String>['area_id', 'scheduled_at'],
  ),
  'idx_time_mission_start': _IndexContract(
    table: 'time_entries',
    columns: <String>['mission_id', 'started_at'],
  ),
  'uq_time_open_timer_work': _IndexContract(
    table: 'time_entries',
    columns: <String>['mission_id'],
    unique: true,
    partial: true,
  ),
  'idx_event_mission_time': _IndexContract(
    table: 'mission_events',
    columns: <String>['mission_id', 'occurred_at'],
  ),
  'idx_notification_due': _IndexContract(
    table: 'notification_schedules',
    columns: <String>['status', 'notify_at'],
  ),
  'idx_tx_date_type': _IndexContract(
    table: 'transactions',
    columns: <String>['occurred_at', 'transaction_type'],
  ),
  'idx_transactions_mission': _IndexContract(
    table: 'transactions',
    columns: <String>['mission_id'],
  ),
  'idx_transactions_related': _IndexContract(
    table: 'transactions',
    columns: <String>['related_transaction_id'],
  ),
  'idx_goal_time': _IndexContract(
    table: 'goal_allocations',
    columns: <String>['goal_id', 'occurred_at'],
  ),
  'idx_journal_time': _IndexContract(
    table: 'journal_entries',
    columns: <String>['occurred_at'],
  ),
  'idx_journal_mission': _IndexContract(
    table: 'journal_entries',
    columns: <String>['mission_id'],
  ),
  'idx_journal_transaction': _IndexContract(
    table: 'journal_entries',
    columns: <String>['transaction_id'],
  ),
  'uq_xp_mission': _IndexContract(
    table: 'xp_transactions',
    columns: <String>['mission_id'],
    unique: true,
    partial: true,
  ),
  'idx_xp_area_time': _IndexContract(
    table: 'xp_transactions',
    columns: <String>['area_id', 'occurred_at'],
  ),
  'idx_xp_time': _IndexContract(
    table: 'xp_transactions',
    columns: <String>['occurred_at'],
  ),
  'idx_title_history_time': _IndexContract(
    table: 'title_history',
    columns: <String>['title_id', 'activated_at'],
  ),
  'uq_title_history_current': _IndexContract(
    table: 'title_history',
    columns: <String>['title_id'],
    unique: true,
    partial: true,
  ),
};

const Set<String> _expectedForeignKeys = <String>{
  'mission_templates.area_id->life_areas.id:RESTRICT',
  'mission_template_objectives.template_id->mission_templates.id:CASCADE',
  'recurrence_rules.template_id->mission_templates.id:CASCADE',
  'missions.template_id->mission_templates.id:SET NULL',
  'missions.area_id->life_areas.id:RESTRICT',
  'mission_objectives.mission_id->missions.id:RESTRICT',
  'time_entries.mission_id->missions.id:RESTRICT',
  'mission_events.mission_id->missions.id:RESTRICT',
  'notification_schedules.mission_id->missions.id:RESTRICT',
  'transactions.mission_id->missions.id:SET NULL',
  'transactions.related_transaction_id->transactions.id:RESTRICT',
  'goal_allocations.goal_id->savings_goals.id:RESTRICT',
  'journal_entries.mission_id->missions.id:SET NULL',
  'journal_entries.transaction_id->transactions.id:SET NULL',
  'journal_attachments.journal_entry_id->journal_entries.id:CASCADE',
  'xp_transactions.area_id->life_areas.id:RESTRICT',
  'xp_transactions.mission_id->missions.id:RESTRICT',
  'xp_transactions.journal_entry_id->journal_entries.id:SET NULL',
  'title_history.title_id->title_definitions.id:RESTRICT',
};

void main() {
  group('schema v1 catalog', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(
        NativeDatabase.memory(),
        utcNowMilliseconds: () => _seedTime,
      );
    });

    tearDown(() => database.close());

    test('contains exactly the 19 approved tables', () async {
      final rows = await database.customSelect('''
        SELECT name
        FROM sqlite_master
        WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
      ''').get();
      final Set<String> actual = rows
          .map((row) => row.read<String>('name'))
          .toSet();

      expect(actual, _expectedTables);
      expect(actual, hasLength(19));
    });

    test('contains exactly the 21 approved explicit indexes', () async {
      final rows = await database.customSelect('''
        SELECT name
        FROM sqlite_master
        WHERE type = 'index' AND name NOT LIKE 'sqlite_autoindex_%'
      ''').get();
      final Set<String> actualNames = rows
          .map((row) => row.read<String>('name'))
          .toSet();

      expect(actualNames, _expectedIndexes.keys.toSet());
      expect(actualNames, hasLength(21));

      for (final MapEntry<String, _IndexContract> expected
          in _expectedIndexes.entries) {
        final indexList = await database
            .customSelect('PRAGMA index_list("${expected.value.table}")')
            .get();
        final indexRow = indexList.singleWhere(
          (row) => row.read<String>('name') == expected.key,
        );
        expect(indexRow.read<int>('unique'), expected.value.unique ? 1 : 0);
        expect(indexRow.read<int>('partial'), expected.value.partial ? 1 : 0);

        final columnRows = await database
            .customSelect('PRAGMA index_info("${expected.key}")')
            .get();
        columnRows.sort(
          (left, right) =>
              left.read<int>('seqno').compareTo(right.read<int>('seqno')),
        );
        expect(
          columnRows.map((row) => row.read<String>('name')).toList(),
          expected.value.columns,
          reason: expected.key,
        );
      }
    });

    test('contains exactly the 19 approved foreign keys and actions', () async {
      final actual = <String>[];

      for (final String table in _expectedTables) {
        final rows = await database
            .customSelect('PRAGMA foreign_key_list("$table")')
            .get();
        for (final row in rows) {
          actual.add(
            '$table.${row.read<String>('from')}'
            '->${row.read<String>('table')}.${row.read<String>('to')}'
            ':${row.read<String>('on_delete')}',
          );
        }
      }

      expect(actual, hasLength(19));
      expect(actual.toSet(), _expectedForeignKeys);
    });

    test(
      'sets user_version, metadata, areas and settings deterministically',
      () async {
        final userVersion = await database
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(userVersion.read<int>('user_version'), 1);

        final metadataRows = await database.customSelect('''
        SELECT "key", value, updated_at
        FROM schema_metadata
        ORDER BY "key"
      ''').get();
        final metadata = <String, ({String value, int updatedAt})>{
          for (final row in metadataRows)
            row.read<String>('key'): (
              value: row.read<String>('value'),
              updatedAt: row.read<int>('updated_at'),
            ),
        };
        expect(metadata, <String, ({String value, int updatedAt})>{
          'created_with': (value: '0.1.0+1', updatedAt: _seedTime),
          'schema_version': (value: '1', updatedAt: _seedTime),
          'seed_version': (value: '1', updatedAt: _seedTime),
        });

        final areaRows = await database.customSelect('''
        SELECT name, icon_key, color_hex, is_default, is_visible, sort_order
        FROM life_areas
        ORDER BY sort_order
      ''').get();
        expect(
          areaRows
              .map(
                (row) => (
                  name: row.read<String>('name'),
                  icon: row.read<String>('icon_key'),
                  color: row.read<String>('color_hex'),
                  isDefault: row.read<int>('is_default'),
                  isVisible: row.read<int>('is_visible'),
                  sortOrder: row.read<int>('sort_order'),
                ),
              )
              .toList(),
          <
            ({
              String name,
              String icon,
              String color,
              int isDefault,
              int isVisible,
              int sortOrder,
            })
          >[
            (
              name: 'Estudios',
              icon: 'school',
              color: '#38BDF8',
              isDefault: 0,
              isVisible: 1,
              sortOrder: 0,
            ),
            (
              name: 'Salud',
              icon: 'favorite',
              color: '#22C55E',
              isDefault: 0,
              isVisible: 1,
              sortOrder: 1,
            ),
            (
              name: 'Proyectos',
              icon: 'code',
              color: '#A855F7',
              isDefault: 0,
              isVisible: 1,
              sortOrder: 2,
            ),
            (
              name: 'Hogar',
              icon: 'home',
              color: '#F59E0B',
              isDefault: 0,
              isVisible: 1,
              sortOrder: 3,
            ),
            (
              name: 'Personal',
              icon: 'person',
              color: '#FF3B3B',
              isDefault: 1,
              isVisible: 1,
              sortOrder: 4,
            ),
          ],
        );

        final titleRows = await database.customSelect('''
        SELECT name, title_kind, rule_key, threshold, is_active
        FROM title_definitions
        ORDER BY rule_key
      ''').get();
        expect(
          titleRows
              .map(
                (row) => (
                  name: row.read<String>('name'),
                  kind: row.read<String>('title_kind'),
                  ruleKey: row.read<String>('rule_key'),
                  threshold: row.read<int>('threshold'),
                  isActive: row.read<int>('is_active'),
                ),
              )
              .toList(),
          <
            ({
              String name,
              String kind,
              String ruleKey,
              int threshold,
              int isActive,
            })
          >[
            (
              name: 'Centinela del hogar',
              kind: 'PERMANENT',
              ruleKey: 'missions.completed.area.hogar',
              threshold: 100,
              isActive: 1,
            ),
            (
              name: 'Ritmo constante',
              kind: 'DYNAMIC',
              ruleKey: 'missions.completed.daily_streak',
              threshold: 7,
              isActive: 1,
            ),
          ],
        );

        final settings = await database
            .customSelect('SELECT * FROM app_settings WHERE id = 1')
            .getSingle();
        expect(settings.read<String>('theme_key'), 'terminal_reinforced');
        expect(settings.read<String>('primary_color'), '#FF3B3B');
        expect(settings.read<int>('large_text'), 0);
        expect(settings.read<int>('reduce_motion'), 0);
        expect(settings.read<int>('high_contrast'), 0);
        expect(settings.read<int>('hide_amounts'), 0);
        expect(settings.read<int>('mission_notifications'), 1);
        expect(settings.read<int>('daily_summary'), 1);
        expect(settings.read<int>('sound_enabled'), 1);
        expect(settings.read<int>('auto_lock_minutes'), 5);
        expect(settings.read<int>('updated_at'), _seedTime);
      },
    );

    test('passes SQLite integrity and foreign-key checks', () async {
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      final integrity = await database
          .customSelect('PRAGMA integrity_check')
          .getSingle();
      expect(integrity.data.values.single, 'ok');
    });
  });

  test('reopening the same v1 database is idempotent', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'bitacora_g1_reopen_',
    );
    final File file = File(p.join(directory.path, 'schema_v1.sqlite'));
    AppDatabase? first;
    AppDatabase? reopened;

    try {
      first = AppDatabase(
        NativeDatabase(file),
        utcNowMilliseconds: () => _seedTime,
      );
      expect(await _count(first, 'life_areas'), 5);
      expect(await _count(first, 'title_definitions'), 2);
      expect(await _count(first, 'schema_metadata'), 3);
      await first.close();
      first = null;

      reopened = AppDatabase(
        NativeDatabase(file),
        utcNowMilliseconds: () => _seedTime + 86400000,
      );
      expect(await _count(reopened, 'life_areas'), 5);
      expect(await _count(reopened, 'title_definitions'), 2);
      expect(await _count(reopened, 'app_settings'), 1);
      expect(await _count(reopened, 'schema_metadata'), 3);

      final metadataTimes = await reopened.customSelect('''
        SELECT DISTINCT updated_at FROM schema_metadata
      ''').get();
      expect(
        metadataTimes.map((row) => row.read<int>('updated_at')).toSet(),
        <int>{_seedTime},
      );
      expect(
        await reopened.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      final integrity = await reopened
          .customSelect('PRAGMA integrity_check')
          .getSingle();
      expect(integrity.data.values.single, 'ok');
    } finally {
      await first?.close();
      await reopened?.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });
}

Future<int> _count(AppDatabase database, String table) async {
  final row = await database
      .customSelect('SELECT COUNT(*) AS value FROM "$table"')
      .getSingle();
  return row.read<int>('value');
}

final class _IndexContract {
  const _IndexContract({
    required this.table,
    required this.columns,
    this.unique = false,
    this.partial = false,
  });

  final String table;
  final List<String> columns;
  final bool unique;
  final bool partial;
}
