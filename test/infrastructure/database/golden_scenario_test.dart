import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/golden_scenario.dart';
import 'schema_v4_expectations.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => GoldenScenario.standard.nowUtcMs,
    );
  });

  tearDown(() => database.close());

  test('GoldenScenario.standard cumple el contrato canónico de A1', () async {
    const scenario = GoldenScenario.standard;

    expect(scenario.nowUtcMs, 1787521320000);
    expect(scenario.timezoneId, 'America/La_Paz');
    expect(scenario.locale, 'es_BO');
    expect(scenario.currencyCode, 'BOB');

    await scenario.seed(database);

    await _expectSchemaAndIntegrity(database);
    await _expectMissions(database);
    await _expectJournal(database);
    await _expectEconomy(database);
    await _expectXp(database);
  });
}

Future<void> _expectSchemaAndIntegrity(AppDatabase database) async {
  final expectedTables = <String>{
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
    ...schemaV4NewTables,
  };

  final tableRows = await database.customSelect('''
        SELECT name
        FROM sqlite_master
        WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
      ''').get();
  expect(
    tableRows.map((row) => row.read<String>('name')).toSet(),
    expectedTables,
  );

  final foreignKeyErrors = await database
      .customSelect('PRAGMA foreign_key_check')
      .get();
  expect(foreignKeyErrors, isEmpty);

  final integrity = await database
      .customSelect('PRAGMA integrity_check')
      .getSingle();
  expect(integrity.read<String>('integrity_check'), 'ok');
}

Future<void> _expectMissions(AppDatabase database) async {
  expect(
    await _scalarInt(database, 'SELECT COUNT(*) AS value FROM missions'),
    8,
  );

  final todayWhere =
      '''
    scheduled_at >= ${GoldenScenario.localDayStartUtcMs}
    AND scheduled_at < ${GoldenScenario.localDayEndUtcMs}
  ''';
  expect(
    await _scalarInt(
      database,
      'SELECT COUNT(*) AS value FROM missions WHERE $todayWhere',
    ),
    5,
  );
  expect(
    await _scalarInt(database, '''
        SELECT COUNT(*) AS value
        FROM missions
        WHERE $todayWhere AND status = 'COMPLETED'
      '''),
    3,
  );
  expect(
    await _scalarInt(database, '''
        SELECT COUNT(*) AS value
        FROM missions
        WHERE $todayWhere AND status = 'ACTIVE'
      '''),
    1,
  );
  expect(
    await _scalarInt(database, '''
        SELECT COUNT(*) AS value
        FROM missions
        WHERE $todayWhere AND status = 'AVAILABLE'
      '''),
    1,
  );

  final laboratory = await database.customSelect('''
        SELECT title, importance, priority, xp_planned, estimated_minutes,
               budget_minor, status
        FROM missions
        WHERE id = '${GoldenScenario.laboratoryMissionId}'
      ''').getSingle();
  expect(laboratory.read<String>('title'), 'Completar laboratorio de redes');
  expect(laboratory.read<String>('importance'), 'IMPORTANT');
  expect(laboratory.read<String>('priority'), 'HIGH');
  expect(laboratory.read<int>('xp_planned'), 50);
  expect(laboratory.read<int>('estimated_minutes'), 90);
  expect(laboratory.read<int>('budget_minor'), 3500);
  expect(laboratory.read<String>('status'), 'ACTIVE');

  final objectives = await database.customSelect('''
        SELECT COUNT(*) AS total,
               SUM(CASE WHEN completed_at IS NOT NULL THEN 1 ELSE 0 END)
                 AS completed
        FROM mission_objectives
        WHERE mission_id = '${GoldenScenario.laboratoryMissionId}'
      ''').getSingle();
  expect(objectives.read<int>('total'), 3);
  expect(objectives.read<int>('completed'), 1);
}

Future<void> _expectJournal(AppDatabase database) async {
  expect(
    await _scalarInt(database, 'SELECT COUNT(*) AS value FROM journal_entries'),
    3,
  );
  expect(
    await _scalarInt(database, '''
        SELECT COUNT(*) AS value
        FROM journal_entries
        WHERE origin_type = 'MANUAL'
      '''),
    2,
  );
  expect(
    await _scalarInt(database, '''
        SELECT COUNT(*) AS value
        FROM journal_entries
        WHERE origin_type = 'MISSION'
          AND mission_id = '${GoldenScenario.laboratoryMissionId}'
      '''),
    1,
  );
  expect(
    await _scalarInt(database, '''
        SELECT COUNT(*) AS value
        FROM journal_attachments
        WHERE kind = 'PHOTO' AND archived_at IS NULL
      '''),
    1,
  );
}

Future<void> _expectEconomy(AppDatabase database) async {
  final total = await _economy(database);
  expect(total.credits - total.debits, 154000);

  final month = await _economy(
    database,
    where:
        '''
      occurred_at >= ${GoldenScenario.localMonthStartUtcMs}
      AND occurred_at < ${GoldenScenario.localMonthEndUtcMs}
    ''',
  );
  expect(month.credits, 185000);
  expect(month.debits, 61000);

  final day = await _economy(
    database,
    where:
        '''
      occurred_at >= ${GoldenScenario.localDayStartUtcMs}
      AND occurred_at < ${GoldenScenario.localDayEndUtcMs}
    ''',
  );
  expect(day.credits, 15000);
  expect(day.debits, 19200);
  expect(day.credits - day.debits, -4200);

  final reserved = await _scalarInt(database, '''
      SELECT COALESCE(SUM(
        CASE direction WHEN 'RESERVE' THEN amount_minor ELSE -amount_minor END
      ), 0) AS value
      FROM goal_allocations
    ''');
  expect(reserved, 30000);
  expect(total.credits - total.debits - reserved, 124000);
}

Future<void> _expectXp(AppDatabase database) async {
  expect(
    await _scalarInt(
      database,
      'SELECT COALESCE(SUM(amount), 0) AS value FROM xp_transactions',
    ),
    4450,
  );
  expect(
    await _scalarInt(database, '''
        SELECT COALESCE(SUM(amount), 0) AS value
        FROM xp_transactions
        WHERE occurred_at >= ${GoldenScenario.localDayStartUtcMs}
          AND occurred_at < ${GoldenScenario.localDayEndUtcMs}
      '''),
    125,
  );
  expect(
    await _scalarInt(database, '''
        SELECT COALESCE(SUM(amount), 0) AS value
        FROM xp_transactions
        WHERE occurred_at >= ${GoldenScenario.localWeekStartUtcMs}
          AND occurred_at < ${GoldenScenario.localDayEndUtcMs}
      '''),
    325,
  );

  final areaRows = await database.customSelect('''
        SELECT life_areas.name AS area, SUM(xp_transactions.amount) AS xp
        FROM xp_transactions
        INNER JOIN life_areas ON life_areas.id = xp_transactions.area_id
        GROUP BY life_areas.id, life_areas.name
      ''').get();
  final xpByArea = <String, int>{
    for (final row in areaRows) row.read<String>('area'): row.read<int>('xp'),
  };
  expect(xpByArea, <String, int>{
    'Estudios': 1200,
    'Salud': 760,
    'Proyectos': 2150,
    'Hogar': 215,
    'Personal': 125,
  });
}

Future<int> _scalarInt(AppDatabase database, String sql) async {
  final row = await database.customSelect(sql).getSingle();
  return row.read<int>('value');
}

Future<({int credits, int debits})> _economy(
  AppDatabase database, {
  String? where,
}) async {
  final row = await database.customSelect('''
        SELECT
          COALESCE(SUM(CASE
            WHEN transaction_type IN ('INCOME', 'REFUND', 'ADJUSTMENT_CREDIT')
              THEN amount_minor
            ELSE 0
          END), 0) AS credits,
          COALESCE(SUM(CASE
            WHEN transaction_type IN ('EXPENSE', 'ADJUSTMENT_DEBIT')
              THEN amount_minor
            ELSE 0
          END), 0) AS debits
        FROM transactions
        ${where == null ? '' : 'WHERE $where'}
      ''').getSingle();
  return (credits: row.read<int>('credits'), debits: row.read<int>('debits'));
}
