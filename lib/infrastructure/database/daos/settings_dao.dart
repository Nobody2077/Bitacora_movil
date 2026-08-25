import 'package:drift/drift.dart';

import '../app_database.dart';
import 'dao_support.dart';

final class SettingsDao {
  SettingsDao(this._database);

  final AppDatabase _database;

  static const Set<String> _reservedMetadataKeys = <String>{
    'schema_version',
    'seed_version',
    'created_with',
  };

  Future<AppSetting> getSettings() async {
    final settings = await (_database.select(
      _database.appSettings,
    )..where((table) => table.id.equals(1))).getSingleOrNull();
    if (settings == null) {
      throw const RecordNotFoundException(table: 'app_settings', key: 1);
    }
    return settings;
  }

  Stream<AppSetting> watchSettings() {
    return (_database.select(
      _database.appSettings,
    )..where((table) => table.id.equals(1))).watchSingle();
  }

  Future<AppSetting> updateSettings(AppSettingsCompanion changes) async {
    if (changes.id.present) {
      throw ArgumentError('The app_settings singleton id cannot change.');
    }
    if (!changes.updatedAt.present) {
      throw ArgumentError('updated_at is mandatory for a settings update.');
    }

    final affected = await (_database.update(
      _database.appSettings,
    )..where((table) => table.id.equals(1))).write(changes);
    if (affected != 1) {
      throw const RecordNotFoundException(table: 'app_settings', key: 1);
    }
    return getSettings();
  }

  Future<String?> getMetadata(String key) async {
    final row = await (_database.select(
      _database.schemaMetadata,
    )..where((table) => table.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Stream<List<SchemaMetadataData>> watchMetadata() {
    return (_database.select(_database.schemaMetadata)
          ..orderBy(<OrderingTerm Function(SchemaMetadata)>[
            (table) => OrderingTerm.asc(table.key),
          ]))
        .watch();
  }

  Future<void> putMetadata({
    required String key,
    required String value,
    required int updatedAtUtcMs,
  }) async {
    if (key.trim().isEmpty) {
      throw ArgumentError.value(key, 'key', 'Must not be blank.');
    }
    if (_reservedMetadataKeys.contains(key)) {
      throw ArgumentError.value(
        key,
        'key',
        'Reserved database metadata is managed by AppDatabase.',
      );
    }
    await _database.customInsert(
      '''
        INSERT INTO schema_metadata ("key", value, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT("key") DO UPDATE SET
          value = excluded.value,
          updated_at = excluded.updated_at
      ''',
      variables: <Variable<Object>>[
        Variable<String>(key),
        Variable<String>(value),
        Variable<int>(updatedAtUtcMs),
      ],
      updates: <ResultSetImplementation<Table, Object?>>{
        _database.schemaMetadata,
      },
    );
  }

  Future<int> getSchemaVersionMirror() async {
    final stored = await getMetadata('schema_version');
    final parsed = int.tryParse(stored ?? '');
    if (parsed == null || parsed < 1) {
      throw const DatabaseInvariantException(
        'schema_metadata does not contain a valid schema_version mirror.',
      );
    }
    return parsed;
  }
}
