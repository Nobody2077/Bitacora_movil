import 'dart:convert';
import 'dart:io';

import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Las 14 tablas que añade v4 (ADR-006).
const Set<String> schemaV4NewTables = <String>{
  'contacts',
  'contact_photos',
  'mission_contacts',
  'journal_entry_contacts',
  'mission_photos',
  'inventory_items',
  'item_photos',
  'projects',
  'project_items',
  'craft_operations',
  'craft_component_ledger',
  'reward_specs',
  'reward_spec_costs',
  'reward_vouchers',
};

/// Crea en crudo el esquema de una versión anterior a partir de su snapshot
/// oficial, sin pasar por `AppDatabase`, y fija su `user_version`.
void createSchemaFromSnapshot(Database database, int version) {
  final snapshot =
      jsonDecode(
            File(
              'drift_schemas/drift_schema_v$version.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;
  for (final fixed
      in (snapshot['fixed_sql']! as List<Object?>)
          .cast<Map<String, Object?>>()) {
    final variants = (fixed['sql']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final sqlite = variants.singleWhere(
      (variant) => variant['dialect'] == 'sqlite',
    );
    database.execute(sqlite['sql']! as String);
  }
  database.execute('PRAGMA user_version = $version');
}

/// Comprueba que la base quedó en v5 completa y sana tras migrar: las tablas
/// de v4 (ADR-006) y el `area_id` de `inventory_items` (D17).
Future<void> expectMigratedToV5(AppDatabase database) async {
  expect(database.schemaVersion, 5);
  final version = await database
      .customSelect('PRAGMA user_version')
      .getSingle();
  expect(version.read<int>('user_version'), 5);
  final mirror = await database.customSelect('''
    SELECT value FROM schema_metadata WHERE "key" = 'schema_version'
  ''').getSingle();
  expect(mirror.read<String>('value'), '5');

  final tables = await database.customSelect('''
    SELECT name FROM sqlite_master
    WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
  ''').get();
  final Set<String> tableNames = tables
      .map((row) => row.read<String>('name'))
      .toSet();
  expect(tableNames, hasLength(33));
  expect(tableNames.containsAll(schemaV4NewTables), isTrue);

  for (final String table in <String>['missions', 'mission_templates']) {
    final columns = await database
        .customSelect('PRAGMA table_info($table)')
        .get();
    expect(
      columns.map((column) => column.read<String>('name')),
      contains('location'),
      reason: table,
    );
  }

  final itemColumns = await database
      .customSelect('PRAGMA table_info(inventory_items)')
      .get();
  final areaColumn = itemColumns.singleWhere(
    (column) => column.read<String>('name') == 'area_id',
  );
  expect(areaColumn.read<int>('notnull'), 0);
  final itemForeignKeys = await database
      .customSelect('PRAGMA foreign_key_list(inventory_items)')
      .get();
  final areaForeignKey = itemForeignKeys.singleWhere(
    (key) => key.read<String>('from') == 'area_id',
  );
  expect(areaForeignKey.read<String>('table'), 'life_areas');
  expect(areaForeignKey.read<String>('on_delete'), 'SET NULL');

  expect(
    await database.customSelect('PRAGMA foreign_key_check').get(),
    isEmpty,
  );
  final integrity = await database
      .customSelect('PRAGMA integrity_check')
      .getSingle();
  expect(integrity.data.values.single, 'ok');
}
