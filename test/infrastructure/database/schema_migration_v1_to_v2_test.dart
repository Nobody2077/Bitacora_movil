import 'dart:convert';
import 'dart:io';

import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/journal/data/drift_journal_repository.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/models/journal_entry.dart'
    as domain;
import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/journal_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'schema_v4_expectations.dart';

const int _nowMs = 1788000000000;

void main() {
  test('migra v1 a v4, conserva el ánimo y añade el modo del tablón', () async {
    final Database rawDatabase = sqlite3.openInMemory();
    _createSchemaV1(rawDatabase);
    rawDatabase.execute('''
      INSERT INTO journal_entries (
        id, origin_type, title, mood, is_private,
        occurred_at, created_at, updated_at
      ) VALUES (
        'legacy-entry', 'MANUAL', 'Entrada anterior', 'FOCUSED', 1,
        $_nowMs, $_nowMs, $_nowMs
      )
    ''');

    final AppDatabase database = AppDatabase(
      NativeDatabase.opened(rawDatabase),
      utcNowMilliseconds: () => _nowMs,
    );
    addTearDown(database.close);
    final DriftJournalRepository repository = DriftJournalRepository(
      JournalDao(database),
    );

    final domain.JournalEntry? legacy = _success(
      await repository.findById('legacy-entry'),
    );
    expect(database.schemaVersion, 4);
    expect(legacy?.mood, domain.JournalMood.focused);

    final domain.JournalEntry happy = domain.JournalEntry(
      id: 'happy-entry',
      origin: domain.JournalOrigin.manual,
      title: 'Un gran día',
      mood: domain.JournalMood.happy,
      isPrivate: true,
      occurredAtUtc: DateTime.fromMillisecondsSinceEpoch(_nowMs, isUtc: true),
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch(_nowMs, isUtc: true),
      updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(_nowMs, isUtc: true),
      attachmentCount: 0,
    );
    _success(await repository.create(happy));
    expect(
      _success(await repository.findById(happy.id))?.mood,
      domain.JournalMood.happy,
    );

    final row = await database.customSelect('''
      SELECT mood, mood_detail
      FROM journal_entries
      WHERE id = 'happy-entry'
    ''').getSingle();
    expect(row.readNullable<String>('mood'), isNull);
    expect(row.read<String>('mood_detail'), 'HAPPY');
    final templateColumns = await database
        .customSelect('PRAGMA table_info(mission_templates)')
        .get();
    expect(
      templateColumns.map((column) => column.read<String>('name')),
      contains('availability_mode'),
    );
    expect(
      await database.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );
    await expectMigratedToV4(database);
  });
}

void _createSchemaV1(Database database) {
  final snapshot =
      jsonDecode(File('drift_schemas/drift_schema_v1.json').readAsStringSync())
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
  database.execute('PRAGMA user_version = 1');
}

T _success<T>(Result<T> result) => result.fold(
  onSuccess: (T value) => value,
  onFailure: (failure) => throw TestFailure(failure.message),
);
