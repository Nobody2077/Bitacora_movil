import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'schema_v4_expectations.dart';

const int _nowMs = 1789500000000;

/// Datos de una base v4 con uso real: lo de v3 más personajes, ubicación y
/// filas de `inventory_items`. La migración a v5 solo añade `area_id`
/// (ADR-006 D17) y se hace sin copia de seguridad, así que ninguna fila
/// previa puede cambiar.
void _seedV4(Database db) {
  db.execute('''
    INSERT INTO life_areas (id, name, icon_key, color_hex, is_default,
      is_visible, sort_order)
    VALUES ('area-estudios', 'Estudios', 'school', '#55E6E6', 1, 1, 0),
           ('area-hogar', 'Hogar', 'home', '#E6B455', 0, 1, 1)
  ''');
  db.execute('''
    INSERT INTO missions (id, template_id, area_id, title, description,
      mission_type, importance, priority, difficulty, is_required, status,
      scheduled_at, xp_planned, completed_at, row_version, location)
    VALUES ('mis-entrega', NULL, 'area-estudios', 'Entregar práctica 4',
      'Cálculo II', 'PRIMARY', 'IMPORTANT', 'URGENT', 'HARD', 1,
      'COMPLETED', ${_nowMs - 86400000}, 80, $_nowMs, 3, 'Universidad')
  ''');
  db.execute('''
    INSERT INTO transactions (id, operation_id, mission_id, transaction_type,
      amount_minor, payment_method, category, note, occurred_at, created_at)
    VALUES ('tx-ingreso', 'op-1', NULL, 'INCOME', 150000, 'BANK', 'Sueldo',
             NULL, $_nowMs, $_nowMs),
           ('tx-audifonos', 'op-2', NULL, 'EXPENSE', 35000, 'CASH',
             'Tecnología', NULL, $_nowMs, $_nowMs)
  ''');
  db.execute('''
    INSERT INTO savings_goals (id, title, target_minor, status, due_date,
      created_at)
    VALUES ('goal-pc', 'PC nueva', 600000, 'ACTIVE', '2026-12-31', $_nowMs)
  ''');
  db.execute('''
    INSERT INTO contacts (id, display_name, created_at, updated_at)
    VALUES ('rocio', 'Lic. Rocío Mamani', $_nowMs, $_nowMs)
  ''');
  db.execute('''
    INSERT INTO mission_contacts (mission_id, contact_id, created_at)
    VALUES ('mis-entrega', 'rocio', $_nowMs)
  ''');
  db.execute('''
    INSERT INTO inventory_items (id, name, description, category, icon_key,
      status, origin, wish_priority, wish_price_minor, wish_goal_id,
      acquired_at, purchase_transaction_id, created_at, updated_at)
    VALUES
      ('wish-pc', 'PC nueva', 'Ryzen 7, 32 GB', 'TECHNOLOGY', 'computer',
        'WISHED', NULL, 'HIGH', 600000, 'goal-pc', NULL, NULL, $_nowMs,
        $_nowMs),
      ('item-audifonos', 'Audífonos', NULL, 'TECHNOLOGY', 'headphones',
        'OWNED', 'PURCHASE', NULL, NULL, NULL, $_nowMs, 'tx-audifonos',
        $_nowMs, $_nowMs)
  ''');
}

/// Copia literal de cada fila existente, solo con las columnas de v4.
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
  test('migra v4 a v5 sin cambiar ninguna fila existente', () async {
    final Database rawDatabase = sqlite3.openInMemory();
    rawDatabase.execute('PRAGMA foreign_keys = ON');
    createSchemaFromSnapshot(rawDatabase, 4);
    _seedV4(rawDatabase);
    final Map<String, List<Map<String, Object?>>> before = _snapshotRows(
      rawDatabase,
    );
    expect(before.keys, hasLength(33));

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

    // La columna nueva nace vacía en las filas que ya existían.
    final items = await database.customSelect('''
      SELECT area_id FROM inventory_items
    ''').get();
    expect(items, hasLength(2));
    expect(
      items.every((row) => row.readNullable<String>('area_id') == null),
      isTrue,
    );

    // Un deseo acepta su área; borrar el área lo deja sin ella.
    await database.customStatement('''
      UPDATE inventory_items SET area_id = 'area-hogar' WHERE id = 'wish-pc'
    ''');
    await database.customStatement('''
      DELETE FROM life_areas WHERE id = 'area-hogar'
    ''');
    final wish = await database.customSelect('''
      SELECT area_id FROM inventory_items WHERE id = 'wish-pc'
    ''').getSingle();
    expect(wish.readNullable<String>('area_id'), isNull);

    // Un área inexistente se rechaza.
    await expectLater(
      database.customStatement('''
        UPDATE inventory_items SET area_id = 'no-existe' WHERE id = 'wish-pc'
      '''),
      throwsA(isA<SqliteException>()),
    );
    expect(
      await database.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );
  });

  test('reabrir una base ya migrada a v5 no vuelve a migrar', () async {
    final Database rawDatabase = sqlite3.openInMemory();
    createSchemaFromSnapshot(rawDatabase, 4);
    _seedV4(rawDatabase);

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
