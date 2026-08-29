import 'dart:convert';
import 'dart:io';

import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const Set<String> _applicationTables = <String>{
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

void main() {
  test('drift_schema_v2.json matches the current schema exactly', () async {
    final snapshotFile = File('drift_schemas/drift_schema_v2.json');
    expect(await snapshotFile.exists(), isTrue);

    final snapshot =
        jsonDecode(await snapshotFile.readAsString()) as Map<String, Object?>;
    final metadata = snapshot['_meta']! as Map<String, Object?>;
    expect(metadata['version'], '1.3.0');

    final entities = (snapshot['entities']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final tableNames = _entityNames(entities, 'table');
    final indexNames = _entityNames(entities, 'index');
    expect(tableNames, _applicationTables);
    expect(tableNames, hasLength(19));
    expect(indexNames, hasLength(21));

    final snapshotSql = <String, String>{};
    for (final fixed
        in (snapshot['fixed_sql']! as List<Object?>)
            .cast<Map<String, Object?>>()) {
      final variants = (fixed['sql']! as List<Object?>)
          .cast<Map<String, Object?>>();
      final sqlite = variants.singleWhere(
        (variant) => variant['dialect'] == 'sqlite',
      );
      snapshotSql[fixed['name']! as String] = _normalizeSql(
        sqlite['sql']! as String,
      );
    }

    final database = AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => 1787521320000,
    );
    addTearDown(database.close);

    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 2);

    final rows = await database.customSelect('''
      SELECT name, sql
      FROM sqlite_master
      WHERE type IN ('table', 'index')
        AND name NOT LIKE 'sqlite_%'
        AND sql IS NOT NULL
    ''').get();
    final actualSql = <String, String>{
      for (final row in rows)
        row.read<String>('name'): _normalizeSql(row.read<String>('sql')),
    };

    expect(snapshotSql.keys.toSet(), actualSql.keys.toSet());
    for (final name in actualSql.keys) {
      expect(snapshotSql[name], actualSql[name], reason: name);
    }
  });
}

Set<String> _entityNames(
  Iterable<Map<String, Object?>> entities,
  String type,
) => entities
    .where((entity) => entity['type'] == type)
    .map((entity) => entity['data']! as Map<String, Object?>)
    .map((data) => data['name']! as String)
    .toSet();

String _normalizeSql(String sql) => sql
    .replaceAll(RegExp(r'\bIF NOT EXISTS\b', caseSensitive: false), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceFirst(RegExp(r';\s*$'), '')
    .trim();
