import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const int _now = 1789000000000;
const String _hash =
    '0000000000000000000000000000000000000000000000000000000000000000';

/// ADR-006: cada CHECK y cada índice único nuevo de v4 rechaza lo que debe.
void main() {
  late AppDatabase db;

  Future<void> run(String sql) => db.customStatement(sql);

  Future<void> rejects(String sql, {String? reason}) async {
    await expectLater(run(sql), throwsA(anything), reason: reason ?? sql);
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory(), utcNowMilliseconds: () => _now);
    await run('''
      INSERT INTO life_areas (id, name, icon_key, color_hex, is_default,
        is_visible, sort_order)
      VALUES ('area-x', 'Proyectos X', 'build', '#55E6E6', 0, 1, 9)
    ''');
    await run('''
      INSERT INTO missions (id, area_id, title, mission_type, is_required,
        status, xp_planned)
      VALUES ('m1', 'area-x', 'Armar robot', 'CUSTOM', 0, 'AVAILABLE', 10),
             ('m2', 'area-x', 'Pintar', 'CUSTOM', 0, 'AVAILABLE', 10)
    ''');
    await run('''
      INSERT INTO contacts (id, display_name, created_at, updated_at)
      VALUES ('diego', 'Diego', $_now, $_now)
    ''');
    await run('''
      INSERT INTO inventory_items (id, name, category, icon_key, status,
        origin, acquired_at, created_at, updated_at)
      VALUES ('arduino', 'Arduino UNO', 'PART', 'chip', 'OWNED', 'GIFT',
        $_now, $_now, $_now)
    ''');
    await run('''
      INSERT INTO projects (id, name, icon_key, kind, status, created_at,
        updated_at)
      VALUES ('robot', 'Robot', 'robot', 'ASSEMBLY', 'PLANNING', $_now, $_now)
    ''');
  });

  tearDown(() => db.close());

  test('misiones: la ubicación no puede quedar vacía ni ser larga', () async {
    await rejects("UPDATE missions SET location = '   ' WHERE id = 'm1'");
    await rejects(
      "UPDATE missions SET location = '${'x' * 121}' WHERE id = 'm1'",
    );
    await run("UPDATE missions SET location = 'Taller' WHERE id = 'm1'");
  });

  test('personajes: todo opcional, pero sin textos vacíos', () async {
    await run('''
      INSERT INTO contacts (id, created_at, updated_at)
      VALUES ('anonimo', $_now, $_now)
    ''');
    await rejects('''
      INSERT INTO contacts (id, display_name, created_at, updated_at)
      VALUES ('vacio', '  ', $_now, $_now)
    ''');
    await rejects('''
      INSERT INTO mission_contacts (mission_id, contact_id, created_at)
      VALUES ('m1', 'nadie', $_now)
    ''', reason: 'FK a un personaje inexistente');
  });

  test('fotos: una vigente por dueño, MIME y hash cerrados', () async {
    String photo(
      String id,
      String table,
      String owner,
      String ownerId, {
      String mime = 'image/jpeg',
      String hash = _hash,
    }) =>
        '''
      INSERT INTO $table (id, $owner, storage_name, mime_type, byte_length,
        cipher_sha256, width_px, height_px, created_at)
      VALUES ('$id', '$ownerId', 'enc-$id', '$mime', 10, '$hash', 1, 1, $_now)
    ''';
    await run(photo('p1', 'contact_photos', 'contact_id', 'diego'));
    await rejects(
      photo('p2', 'contact_photos', 'contact_id', 'diego'),
      reason: 'segunda foto vigente',
    );
    await run(photo('p3', 'mission_photos', 'mission_id', 'm1'));
    await rejects(photo('p4', 'mission_photos', 'mission_id', 'm1'));
    await run(photo('p5', 'item_photos', 'item_id', 'arduino'));
    await rejects(photo('p6', 'item_photos', 'item_id', 'arduino'));
    await rejects(
      photo('p7', 'mission_photos', 'mission_id', 'm2', mime: 'image/gif'),
    );
    await rejects(
      photo('p8', 'mission_photos', 'mission_id', 'm2', hash: 'Z' * 64),
    );
  });

  test('inventario: estados coherentes', () async {
    Future<void> item(String id, String fields, String values) => rejects('''
      INSERT INTO inventory_items (id, name, category, icon_key, created_at,
        updated_at, $fields)
      VALUES ('$id', 'X', 'OTHER', 'box', $_now, $_now, $values)
    ''', reason: id);
    await item('sin-prioridad', 'status', "'WISHED'");
    await item(
      'deseo-con-origen',
      'status, wish_priority, origin',
      "'WISHED', 'LOW', 'GIFT'",
    );
    await item('propio-sin-origen', 'status', "'OWNED'");
    await item(
      'equipado-sin-zona',
      'status, origin, acquired_at, is_equipped',
      "'OWNED', 'GIFT', $_now, 1",
    );
    await item(
      'integrado-sin-padre',
      'status, origin, acquired_at',
      "'INTEGRATED', 'GIFT', $_now",
    );
    await item(
      'retirado-sin-fecha',
      'status, origin, acquired_at',
      "'RETIRED', 'GIFT', $_now",
    );
    await rejects('''
      INSERT INTO inventory_items (id, name, category, icon_key, status,
        origin, acquired_at, created_at, updated_at)
      VALUES ('categoria', 'X', 'FOOD', 'box', 'OWNED', 'GIFT', $_now,
        $_now, $_now)
    ''', reason: 'categoría fuera de la lista');
    await item(
      'zona',
      'status, origin, acquired_at, body_zone',
      "'OWNED', 'GIFT', $_now, 'TAIL'",
    );
    await item(
      'compra-sin-origen-compra',
      'status, origin, acquired_at, purchase_transaction_id',
      "'OWNED', 'GIFT', $_now, 'tx'",
    );
    await rejects(
      "UPDATE inventory_items SET parent_item_id = id, status = 'INTEGRATED' "
      "WHERE id = 'arduino'",
      reason: 'un objeto no puede integrarse en sí mismo',
    );
  });

  test('proyectos: tipos, estados y dueños de cada elemento', () async {
    await rejects('''
      INSERT INTO projects (id, name, icon_key, kind, status, completed_at,
        created_at, updated_at)
      VALUES ('setup', 'Setup', 'desk', 'COLLECTION', 'ASSEMBLED', $_now,
        $_now, $_now)
    ''', reason: 'Reunir no se arma');
    await rejects('''
      INSERT INTO projects (id, name, icon_key, kind, status, completed_at,
        created_at, updated_at)
      VALUES ('pc', 'PC', 'pc', 'ASSEMBLY', 'COMPLETED', $_now, $_now, $_now)
    ''', reason: 'Armar no se «completa»');
    await rejects('''
      INSERT INTO projects (id, name, icon_key, kind, status, completed_at,
        result_item_id, created_at, updated_at)
      VALUES ('pc', 'PC', 'pc', 'ASSEMBLY', 'ASSEMBLED', $_now, NULL, $_now,
        $_now)
    ''', reason: 'armado sin objeto resultado');
    await run('''
      INSERT INTO project_items (id, project_id, owner_type, item_id,
        position, created_at)
      VALUES ('e1', 'robot', 'SELF', 'arduino', 0, $_now)
    ''');
    await run('''
      INSERT INTO project_items (id, project_id, owner_type, contact_id,
        label, position, created_at)
      VALUES ('e2', 'robot', 'CONTACT', 'diego', 'Chasis', 1, $_now)
    ''');
    await rejects('''
      INSERT INTO project_items (id, project_id, owner_type, label, position,
        created_at)
      VALUES ('e3', 'robot', 'OTHER', 'Cable', 2, $_now)
    ''', reason: 'otra persona sin nombre');
    await rejects('''
      INSERT INTO project_items (id, project_id, owner_type, contact_id,
        position, created_at)
      VALUES ('e4', 'robot', 'CONTACT', 'diego', 3, $_now)
    ''', reason: 'elemento ajeno sin etiqueta');
    await rejects('''
      INSERT INTO project_items (id, project_id, owner_type, item_id,
        position, created_at)
      VALUES ('e5', 'robot', 'SELF', 'arduino', 0, $_now)
    ''', reason: 'posición repetida');
    await run("UPDATE projects SET mission_id = 'm1' WHERE id = 'robot'");
    await rejects('''
      INSERT INTO projects (id, name, icon_key, kind, status, mission_id,
        created_at, updated_at)
      VALUES ('otro', 'Otro', 'x', 'COLLECTION', 'PLANNING', 'm1', $_now,
        $_now)
      ''', reason: 'una misión tiene como mucho un proyecto');
  });

  test('creación: libro de componentes, recompensas y vales', () async {
    await rejects('''
      INSERT INTO craft_operations (id, operation_id, kind, occurred_at)
      VALUES ('c0', 'op0', 'MISSION_GRANT', $_now)
    ''', reason: 'concesión sin misión');
    await run('''
      INSERT INTO craft_operations (id, operation_id, kind, mission_id,
        occurred_at)
      VALUES ('c1', 'op1', 'MISSION_GRANT', 'm1', $_now)
    ''');
    await rejects('''
      INSERT INTO craft_operations (id, operation_id, kind, mission_id,
        occurred_at)
      VALUES ('c2', 'op2', 'MISSION_GRANT', 'm1', $_now)
    ''', reason: 'una sola concesión por misión');
    await rejects('''
      INSERT INTO craft_operations (id, operation_id, kind, occurred_at)
      VALUES ('c3', 'op1', 'CONVERT', $_now)
    ''', reason: 'operation_id repetido');
    await rejects('''
      INSERT INTO craft_component_ledger (id, craft_operation_id, rarity,
        amount)
      VALUES ('l0', 'c1', 'MYTHIC', 1)
    ''');
    await rejects('''
      INSERT INTO craft_component_ledger (id, craft_operation_id, rarity,
        amount)
      VALUES ('l1', 'c1', 'COMMON', 0)
    ''');
    await rejects('''
      INSERT INTO reward_specs (id, name, icon_key, target_item_id,
        target_project_id, created_at)
      VALUES ('r0', 'X', 'x', 'arduino', 'robot', $_now)
    ''', reason: 'dos destinos a la vez');
    await run('''
      INSERT INTO reward_specs (id, name, icon_key, created_at)
      VALUES ('r1', 'Tarde libre', 'sofa', $_now)
    ''');
    await rejects('''
      INSERT INTO reward_spec_costs (reward_spec_id, rarity, quantity)
      VALUES ('r1', 'RARE', 0)
    ''');
    await run('''
      INSERT INTO craft_operations (id, operation_id, kind, occurred_at)
      VALUES ('c4', 'op4', 'REDEEM', $_now)
    ''');
    await rejects('''
      INSERT INTO reward_vouchers (id, reward_spec_id, redeem_operation_id,
        status, redeemed_at)
      VALUES ('v0', 'r1', 'c4', 'USED', $_now)
    ''', reason: 'usado sin fecha');
    await rejects('''
      INSERT INTO reward_vouchers (id, reward_spec_id, redeem_operation_id,
        status, redeemed_at, abandoned_at)
      VALUES ('v1', 'r1', 'c4', 'ABANDONED', $_now, $_now)
    ''', reason: 'abandonado sin devolución');
    await run('''
      INSERT INTO reward_vouchers (id, reward_spec_id, redeem_operation_id,
        status, redeemed_at)
      VALUES ('v2', 'r1', 'c4', 'AVAILABLE', $_now)
    ''');
  });
}
