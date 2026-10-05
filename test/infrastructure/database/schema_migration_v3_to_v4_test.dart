import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'schema_v4_expectations.dart';

const int _nowMs = 1789000000000;

/// Datos de una base v3 con uso real: misiones, plantillas, tiempo, dinero,
/// metas, bitácora con foto y XP. La migración a v4 es aditiva y se hace sin
/// copia de seguridad (ADR-006 D2), así que ninguna fila previa puede cambiar.
void _seedV3(Database db) {
  db.execute('''
    INSERT INTO life_areas (id, name, icon_key, color_hex, is_default,
      is_visible, sort_order)
    VALUES ('area-estudios', 'Estudios', 'school', '#55E6E6', 1, 1, 0),
           ('area-salud', 'Salud', 'favorite', '#45D483', 0, 1, 1)
  ''');
  db.execute('''
    INSERT INTO mission_templates (id, area_id, title, mission_type,
      importance, priority, difficulty, is_required, xp_reward,
      availability_mode, is_active)
    VALUES ('tpl-rutina', 'area-salud', 'Rutina de fuerza', 'DAILY',
      'NORMAL', 'HIGH', 'MEDIUM', 0, 30, 'BOARD', 1)
  ''');
  db.execute('''
    INSERT INTO missions (id, template_id, area_id, title, description,
      mission_type, importance, priority, difficulty, is_required, status,
      scheduled_at, xp_planned, completed_at, row_version)
    VALUES
      ('mis-entrega', NULL, 'area-estudios', 'Entregar práctica 4',
        'Cálculo II', 'PRIMARY', 'IMPORTANT', 'URGENT', 'HARD', 1,
        'COMPLETED', ${_nowMs - 86400000}, 80, $_nowMs, 3),
      ('mis-rutina', 'tpl-rutina', 'area-salud', 'Rutina de fuerza', NULL,
        'DAILY', 'NORMAL', 'HIGH', 'MEDIUM', 0, 'AVAILABLE', $_nowMs, 30,
        NULL, 1)
  ''');
  db.execute('''
    INSERT INTO mission_objectives (id, mission_id, description, position,
      completed_at, created_at)
    VALUES ('obj-1', 'mis-entrega', 'Resolver ejercicios 1-10', 0, $_nowMs,
      $_nowMs)
  ''');
  db.execute('''
    INSERT INTO time_entries (id, mission_id, source, segment_type,
      started_at, ended_at, duration_seconds, created_at)
    VALUES ('time-1', 'mis-entrega', 'TIMER', 'WORK', ${_nowMs - 3600000},
      $_nowMs, 3600, $_nowMs)
  ''');
  db.execute('''
    INSERT INTO transactions (id, operation_id, mission_id, transaction_type,
      amount_minor, payment_method, category, note, occurred_at, created_at)
    VALUES ('tx-ingreso', 'op-1', NULL, 'INCOME', 150000, 'BANK', 'Sueldo',
             NULL, $_nowMs, $_nowMs),
           ('tx-libro', 'op-2', 'mis-entrega', 'EXPENSE', 12000, 'CASH',
             'Libros', 'Stewart', $_nowMs, $_nowMs)
  ''');
  db.execute('''
    INSERT INTO savings_goals (id, title, target_minor, status, due_date,
      created_at)
    VALUES ('goal-pc', 'PC nueva', 600000, 'ACTIVE', '2026-12-31', $_nowMs)
  ''');
  db.execute('''
    INSERT INTO goal_allocations (id, operation_id, goal_id, direction,
      amount_minor, occurred_at, created_at)
    VALUES ('alloc-1', 'op-3', 'goal-pc', 'RESERVE', 20000, $_nowMs, $_nowMs)
  ''');
  db.execute('''
    INSERT INTO journal_entries (id, origin_type, mission_id, title, body,
      mood_detail, is_private, occurred_at, created_at, updated_at)
    VALUES ('entry-1', 'MISSION', 'mis-entrega', 'Entregué la práctica',
      'Me costó el ejercicio 7.', 'MOTIVATED', 1, $_nowMs, $_nowMs, $_nowMs)
  ''');
  db.execute('''
    INSERT INTO journal_attachments (id, journal_entry_id, kind, storage_name,
      mime_type, byte_length, cipher_sha256, width_px, height_px, position,
      created_at)
    VALUES ('photo-1', 'entry-1', 'PHOTO', 'enc-photo-1', 'image/jpeg', 2048,
      '${'a' * 64}', 1200, 900, 0, $_nowMs)
  ''');
  db.execute('''
    INSERT INTO xp_transactions (id, area_id, mission_id, source_type, amount,
      occurred_at)
    VALUES ('xp-1', 'area-estudios', 'mis-entrega', 'MISSION', 80, $_nowMs)
  ''');
}

/// Copia literal de cada fila existente, solo con las columnas de v3.
Map<String, List<Map<String, Object?>>> _snapshotRows(Database db) {
  final Map<String, List<Map<String, Object?>>> rows =
      <String, List<Map<String, Object?>>>{};
  final ResultSet tables = db.select('''
    SELECT name FROM sqlite_master
    WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
  ''');
  for (final Row table in tables) {
    final String name = table['name'] as String;
    rows[name] = db
        .select('SELECT rowid AS _rowid, * FROM "$name" ORDER BY rowid')
        .map((Row row) => Map<String, Object?>.of(row))
        .toList();
  }
  return rows;
}

void main() {
  test('migra v3 a v5 sin cambiar ninguna fila existente', () async {
    final Database rawDatabase = sqlite3.openInMemory();
    rawDatabase.execute('PRAGMA foreign_keys = ON');
    createSchemaFromSnapshot(rawDatabase, 3);
    _seedV3(rawDatabase);
    final Map<String, List<Map<String, Object?>>> before = _snapshotRows(
      rawDatabase,
    );
    expect(before.keys, hasLength(19));

    final AppDatabase database = AppDatabase(
      NativeDatabase.opened(rawDatabase),
      utcNowMilliseconds: () => _nowMs,
    );
    addTearDown(database.close);
    await expectMigratedToV5(database);

    for (final MapEntry<String, List<Map<String, Object?>>> table
        in before.entries) {
      // El espejo de la versión cambia por diseño.
      if (table.key == 'schema_metadata') {
        continue;
      }
      for (final Map<String, Object?> old in table.value) {
        final List<String> columns = old.keys
            .where((String column) => column != '_rowid')
            .toList();
        final ResultSet after = rawDatabase.select(
          'SELECT ${columns.map((c) => '"$c"').join(', ')} '
          'FROM "${table.key}" WHERE rowid = ?',
          <Object?>[old['_rowid']],
        );
        expect(after, hasLength(1), reason: '${table.key} ${old['_rowid']}');
        expect(
          Map<String, Object?>.of(after.single),
          Map<String, Object?>.of(old)..remove('_rowid'),
          reason: table.key,
        );
      }
    }

    // Las columnas nuevas nacen vacías en las filas que ya existían.
    final missions = await database.customSelect('''
      SELECT location FROM missions
    ''').get();
    expect(missions, hasLength(2));
    expect(
      missions.every((row) => row.readNullable<String>('location') == null),
      isTrue,
    );
    final template = await database.customSelect('''
      SELECT location FROM mission_templates WHERE id = 'tpl-rutina'
    ''').getSingle();
    expect(template.readNullable<String>('location'), isNull);

    // Las tablas nuevas nacen vacías y aceptan datos con sus vínculos.
    for (final String table in schemaV4NewTables) {
      final count = await database
          .customSelect('SELECT COUNT(*) AS n FROM "$table"')
          .getSingle();
      expect(count.read<int>('n'), 0, reason: table);
    }
    await database.customStatement('''
      INSERT INTO contacts (id, display_name, created_at, updated_at)
      VALUES ('rocio', 'Lic. Rocío Mamani', $_nowMs, $_nowMs)
    ''');
    await database.customStatement('''
      INSERT INTO mission_contacts (mission_id, contact_id, created_at)
      VALUES ('mis-entrega', 'rocio', $_nowMs)
    ''');
    await database.customStatement('''
      UPDATE missions SET location = 'Universidad' WHERE id = 'mis-entrega'
    ''');
    expect(
      await database.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );
  });

  test('reabrir una base ya migrada desde v3 no vuelve a migrar', () async {
    final Database rawDatabase = sqlite3.openInMemory();
    createSchemaFromSnapshot(rawDatabase, 3);
    _seedV3(rawDatabase);

    final AppDatabase first = AppDatabase(
      NativeDatabase.opened(rawDatabase, closeUnderlyingOnClose: false),
      utcNowMilliseconds: () => _nowMs,
    );
    await expectMigratedToV5(first);
    await first.close();

    final AppDatabase reopened = AppDatabase(
      NativeDatabase.opened(rawDatabase),
      utcNowMilliseconds: () => _nowMs,
    );
    addTearDown(reopened.close);
    await expectMigratedToV5(reopened);
  });
}
