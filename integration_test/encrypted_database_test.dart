import 'dart:convert';
import 'dart:io';

import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/connection/encrypted_database_connection.dart';
import 'package:bitacora_rpg_personal/infrastructure/security/database_key_store.dart';
import 'package:bitacora_rpg_personal/infrastructure/security/method_channel_database_key_store.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const String storageId = 'test_encrypted_database_a1';
  const MethodChannelDatabaseKeyStore keyStore =
      MethodChannelDatabaseKeyStore();
  const EncryptedDatabaseConnection connection = EncryptedDatabaseConnection(
    keyStore: keyStore,
  );

  late File databaseFile;

  setUp(() async {
    final Directory supportDirectory = await getApplicationSupportDirectory();
    final Directory testDirectory = Directory(
      p.join(supportDirectory.path, 'integration_test'),
    );
    await testDirectory.create(recursive: true);
    databaseFile = File(p.join(testDirectory.path, 'encrypted_a1.sqlite'));

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

  testWidgets(
    'opens encrypted, reopens with the same key, and fails closed without it',
    (WidgetTester _) async {
      AppDatabase? database;
      QueryExecutor? executor;

      try {
        executor = await connection.open(
          databaseFile: databaseFile,
          storageId: storageId,
        );
        database = AppDatabase(
          executor,
          utcNowMilliseconds: () => 1787521320000,
        );
        executor = null;

        final QueryRow cipherRow = await database
            .customSelect('PRAGMA cipher')
            .getSingle();
        expect(cipherRow.data.values.single, 'chacha20');

        final QueryRow foreignKeyRow = await database
            .customSelect('PRAGMA foreign_keys')
            .getSingle();
        expect(foreignKeyRow.data.values.single, 1);

        final QueryRow tableCount = await database.customSelect('''
              SELECT COUNT(*) AS value
              FROM sqlite_master
              WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
            ''').getSingle();
        expect(tableCount.read<int>('value'), 19);
        expect(await database.select(database.lifeAreas).get(), hasLength(5));

        await database.customStatement('''
            INSERT INTO schema_metadata ("key", value, updated_at)
            VALUES ('integration_probe', 'persisted', 1787521320000)
          ''');
        await database.close();
        database = null;

        final Uint8List encryptedBytes = await databaseFile.readAsBytes();
        final List<int> fileHeader = encryptedBytes
            .take(16)
            .toList(growable: false);
        expect(
          fileHeader,
          isNot(orderedEquals(utf8.encode('SQLite format 3\u0000'))),
        );

        final String firstKey = await keyStore.getOrCreateDatabaseKey(
          databaseExists: true,
          storageId: storageId,
        );
        final String reusedKey = await keyStore.getOrCreateDatabaseKey(
          databaseExists: true,
          storageId: storageId,
        );
        expect(
          reusedKey == firstKey,
          isTrue,
          reason: 'Android Keystore must unwrap the same database key.',
        );

        executor = await connection.open(
          databaseFile: databaseFile,
          storageId: storageId,
        );
        database = AppDatabase(
          executor,
          utcNowMilliseconds: () => 1787521320000,
        );
        executor = null;
        final QueryRow persistedRow = await database.customSelect('''
              SELECT value
              FROM schema_metadata
              WHERE "key" = 'integration_probe'
            ''').getSingle();
        expect(persistedRow.read<String>('value'), 'persisted');
        await database.close();
        database = null;

        final Uint8List bytesBeforeWrongKey = await databaseFile.readAsBytes();

        final String wrongKey = firstKey == '0' * 64 ? 'f' * 64 : '0' * 64;
        final EncryptedDatabaseConnection wrongKeyConnection =
            EncryptedDatabaseConnection(
              keyStore: _FixedDatabaseKeyStore(wrongKey),
            );
        QueryExecutor? wrongKeyExecutor;
        try {
          wrongKeyExecutor = await wrongKeyConnection.open(
            databaseFile: databaseFile,
            storageId: storageId,
          );
          await expectLater(
            wrongKeyExecutor.ensureOpen(const _IntegrationTestExecutorUser()),
            throwsA(
              isA<EncryptedDatabaseOpenException>().having(
                (EncryptedDatabaseOpenException error) => error.failure,
                'failure',
                EncryptedDatabaseOpenFailure.schemaUnreadable,
              ),
            ),
          );
        } finally {
          await wrongKeyExecutor?.close();
        }

        final Uint8List bytesAfterWrongKey = await databaseFile.readAsBytes();
        expect(
          listEquals(bytesAfterWrongKey, bytesBeforeWrongKey),
          isTrue,
          reason: 'A rejected key must not mutate the encrypted database.',
        );

        await keyStore.clearTestMaterial(storageId: storageId);

        await expectLater(
          connection.open(databaseFile: databaseFile, storageId: storageId),
          throwsA(
            isA<DatabaseKeyStoreException>().having(
              (DatabaseKeyStoreException error) => error.code,
              'code',
              'KEY_MISSING_FOR_EXISTING_DATABASE',
            ),
          ),
        );
      } finally {
        await database?.close();
        await executor?.close();
      }
    },
    skip: !Platform.isAndroid,
  );
}

final class _FixedDatabaseKeyStore implements DatabaseKeyStore {
  const _FixedDatabaseKeyStore(this.keyHex);

  final String keyHex;

  @override
  Future<String> getOrCreateDatabaseKey({
    required bool databaseExists,
    required String storageId,
  }) async => keyHex;
}

final class _IntegrationTestExecutorUser implements QueryExecutorUser {
  const _IntegrationTestExecutorUser();

  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
