import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => 1787521320000,
    );
  });

  tearDown(() => database.close());

  test('A8 conserva indices en consultas criticas', () async {
    await _expectIndex(
      database,
      sql: '''
        EXPLAIN QUERY PLAN
        SELECT id
        FROM missions
        WHERE status = 'COMPLETED'
          AND scheduled_at >= 1779676920000
          AND scheduled_at < 1787521320000
        ORDER BY scheduled_at, id
      ''',
      table: 'missions',
      index: 'idx_missions_status_date',
    );
    await _expectIndex(
      database,
      sql: '''
        EXPLAIN QUERY PLAN
        SELECT
          SUM(CASE
            WHEN transaction_type IN (
              'INCOME', 'REFUND', 'ADJUSTMENT_CREDIT'
            ) THEN amount_minor
            ELSE 0
          END) AS credits,
          SUM(CASE
            WHEN transaction_type IN ('EXPENSE', 'ADJUSTMENT_DEBIT')
              THEN amount_minor
            ELSE 0
          END) AS debits
        FROM transactions
        WHERE occurred_at >= 1779676920000
          AND occurred_at < 1787521320000
      ''',
      table: 'transactions',
      index: 'idx_tx_date_type',
    );
    await _expectIndex(
      database,
      sql: '''
        EXPLAIN QUERY PLAN
        SELECT id
        FROM journal_entries
        WHERE occurred_at >= 1779676920000
          AND occurred_at < 1787521320000
          AND archived_at IS NULL
        ORDER BY occurred_at DESC, id DESC
      ''',
      table: 'journal_entries',
      index: 'idx_journal_time',
    );
    await _expectIndex(
      database,
      sql: '''
        EXPLAIN QUERY PLAN
        SELECT area_id, SUM(amount)
        FROM xp_transactions
        WHERE occurred_at >= 1779676920000
          AND occurred_at < 1787521320000
        GROUP BY area_id
      ''',
      table: 'xp_transactions',
      index: 'idx_xp_time',
    );
  });
}

Future<void> _expectIndex(
  AppDatabase database, {
  required String sql,
  required String table,
  required String index,
}) async {
  final rows = await database.customSelect(sql).get();
  final details = rows
      .map((row) => row.read<String>('detail'))
      .toList(growable: false);
  expect(
    details.any((detail) => detail.contains(index)),
    isTrue,
    reason: '$table debe usar $index. Plan obtenido: $details',
  );
  expect(
    details.any((detail) => detail == 'SCAN $table'),
    isFalse,
    reason: '$table no debe degradarse a un escaneo completo: $details',
  );
}
