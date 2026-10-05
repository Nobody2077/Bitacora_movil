import 'dart:convert';
import 'dart:io';

import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'schema_v4_expectations.dart';

const int _nowMs = 1788000000000;

void main() {
  test('migra v2 a v5 y conserva plantillas como automáticas', () async {
    final Database rawDatabase = sqlite3.openInMemory();
    _createSchemaV2(rawDatabase);
    rawDatabase.execute('''
      INSERT INTO life_areas (
        id, name, icon_key, color_hex, is_default, is_visible, sort_order
      ) VALUES ('legacy-area', 'Anterior', 'home', '#00FFFF', 1, 1, 0)
    ''');
    rawDatabase.execute('''
      INSERT INTO mission_templates (
        id, area_id, title, mission_type, importance, priority,
        is_required, xp_reward, is_active
      ) VALUES (
        'legacy-template', 'legacy-area', 'Rutina anterior', 'DAILY',
        'NORMAL', 'NORMAL', 0, 25, 1
      )
    ''');

    final AppDatabase database = AppDatabase(
      NativeDatabase.opened(rawDatabase),
      utcNowMilliseconds: () => _nowMs,
    );
    addTearDown(database.close);

    final template = await (database.select(
      database.missionTemplates,
    )..where((row) => row.id.equals('legacy-template'))).getSingle();
    expect(database.schemaVersion, 5);
    expect(template.availabilityMode, 'AUTOMATIC');

    await expectMigratedToV5(database);
  });
}

void _createSchemaV2(Database database) {
  final snapshot =
      jsonDecode(File('drift_schemas/drift_schema_v2.json').readAsStringSync())
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
  database.execute('PRAGMA user_version = 2');
}
