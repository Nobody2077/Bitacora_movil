import 'dart:convert';
import 'dart:io';

import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/connection/encrypted_database_connection.dart';
import 'package:bitacora_rpg_personal/infrastructure/security/method_channel_database_key_store.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const storageId = 'test_a8_performance';
  const keyStore = MethodChannelDatabaseKeyStore();
  const connection = EncryptedDatabaseConnection(keyStore: keyStore);

  late File databaseFile;

  setUp(() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final testDirectory = Directory(
      p.join(supportDirectory.path, 'integration_test'),
    );
    await testDirectory.create(recursive: true);
    databaseFile = File(p.join(testDirectory.path, 'a8_performance.sqlite'));
    if (await databaseFile.exists()) {
      await databaseFile.delete();
    }
    await keyStore.clearTestMaterial(storageId: storageId);
  });

  tearDown(() async {
    if (await databaseFile.exists()) {
      await databaseFile.delete();
    }
    await keyStore.clearTestMaterial(storageId: storageId);
  });

  testWidgets('A8 mide la base cifrada con el dataset extenso', (_) async {
    QueryExecutor executor = await connection.open(
      databaseFile: databaseFile,
      storageId: storageId,
    );
    AppDatabase database = AppDatabase(
      executor,
      utcNowMilliseconds: () => _nowUtcMs,
    );
    await database.customSelect('SELECT 1').getSingle();
    await _seedExtensiveDataset(database);

    final beforeReadRss = ProcessInfo.currentRss;
    final firstRead = Stopwatch()..start();
    final missions = await database.customSelect('''
      SELECT id, title, scheduled_at, status
      FROM missions
      WHERE scheduled_at >= ${_nowUtcMs - _ninetyDaysMs}
        AND scheduled_at < $_nowUtcMs
        AND archived_at IS NULL
      ORDER BY scheduled_at DESC, id DESC
      LIMIT 200
    ''').get();
    firstRead.stop();

    final dashboard = Stopwatch()..start();
    final dashboardRows = await database.customSelect('''
      SELECT
        COALESCE(SUM(CASE
          WHEN transaction_type IN (
            'INCOME', 'REFUND', 'ADJUSTMENT_CREDIT'
          ) THEN amount_minor
          ELSE 0
        END), 0) AS credits,
        COALESCE(SUM(CASE
          WHEN transaction_type IN ('EXPENSE', 'ADJUSTMENT_DEBIT')
            THEN amount_minor
          ELSE 0
        END), 0) AS debits
      FROM transactions
      WHERE occurred_at >= ${_nowUtcMs - _ninetyDaysMs}
        AND occurred_at < $_nowUtcMs
    ''').getSingle();
    dashboard.stop();
    final readRssDelta = ProcessInfo.currentRss - beforeReadRss;

    expect(missions, hasLength(200));
    expect(dashboardRows.read<int>('credits'), greaterThan(0));
    expect(dashboardRows.read<int>('debits'), greaterThan(0));
    expect(firstRead.elapsedMilliseconds, lessThan(300));
    expect(dashboard.elapsedMilliseconds, lessThan(150));
    expect(readRssDelta, lessThan(128 * 1024 * 1024));

    await database.close();

    final secureOpen = Stopwatch()..start();
    executor = await connection.open(
      databaseFile: databaseFile,
      storageId: storageId,
    );
    database = AppDatabase(executor, utcNowMilliseconds: () => _nowUtcMs);
    final schemaVersion = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    secureOpen.stop();

    expect(schemaVersion.data.values.single, 1);
    expect(secureOpen.elapsedMilliseconds, lessThan(1000));

    final metrics = <String, Object>{
      'schemaVersion': 1,
      'missions': 1000,
      'transactions': 5000,
      'secureOpenMs': secureOpen.elapsedMilliseconds,
      'firstReadMs': firstRead.elapsedMilliseconds,
      'dashboardMs': dashboard.elapsedMilliseconds,
      'readRssDeltaBytes': readRssDelta,
    };
    // A single machine-readable line is retained by the A8 gate as evidence.
    // ignore: avoid_print
    print('A8_METRICS ${jsonEncode(metrics)}');

    await database.close();
  });
}

const int _nowUtcMs = 1787521320000;
const int _ninetyDaysMs = 90 * 24 * 60 * 60 * 1000;
const int _hourMs = 60 * 60 * 1000;

Future<void> _seedExtensiveDataset(AppDatabase database) async {
  final area = await database.customSelect('''
    SELECT id FROM life_areas ORDER BY sort_order, id LIMIT 1
  ''').getSingle();
  final areaId = area.read<String>('id');

  await database.batch((batch) {
    for (var index = 0; index < 1000; index += 1) {
      final scheduledAt = _nowUtcMs - ((index + 1) * _hourMs);
      batch.customStatement(
        '''
          INSERT INTO missions (
            id, area_id, title, mission_type, importance, priority,
            is_required, status, scheduled_at, xp_planned, row_version
          ) VALUES (?, ?, ?, 'CUSTOM', 'NORMAL', 'NORMAL', 0, 'AVAILABLE', ?, 10, 1)
        ''',
        <Object?>[
          'a8-mission-${index.toString().padLeft(4, '0')}',
          areaId,
          'Mision de rendimiento $index',
          scheduledAt,
        ],
      );
    }
    for (var index = 0; index < 5000; index += 1) {
      final occurredAt = _nowUtcMs - ((index + 1) * _hourMs);
      final transactionType = index.isEven ? 'INCOME' : 'EXPENSE';
      batch.customStatement(
        '''
          INSERT INTO transactions (
            id, operation_id, transaction_type, amount_minor,
            payment_method, occurred_at, created_at
          ) VALUES (?, ?, ?, ?, 'BANK', ?, ?)
        ''',
        <Object?>[
          'a8-transaction-${index.toString().padLeft(4, '0')}',
          'a8-operation-${index.toString().padLeft(4, '0')}',
          transactionType,
          100 + index,
          occurredAt,
          occurredAt,
        ],
      );
    }
  });
}
