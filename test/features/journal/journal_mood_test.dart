import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/journal/data/drift_journal_repository.dart';
import 'package:bitacora_rpg_personal/features/journal/domain/models/journal_entry.dart'
    as domain;
import 'package:bitacora_rpg_personal/features/journal/presentation/journal_presentation_support.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/journal_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('los ocho estados tienen etiqueta y conservan su identidad', () async {
    final AppDatabase database = AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => 1788000000000,
    );
    addTearDown(database.close);
    final DriftJournalRepository repository = DriftJournalRepository(
      JournalDao(database),
    );
    final DateTime now = DateTime.utc(2026, 8, 29, 12);

    expect(domain.JournalMood.values, hasLength(8));
    expect(domain.JournalMood.values.map(journalMoodLabel).toSet(), <String>{
      'Feliz',
      'Motivado',
      'Enfocado',
      'Tranquilo',
      'Neutral',
      'Ansioso',
      'Triste',
      'Cansado',
    });

    for (final domain.JournalMood mood in domain.JournalMood.values) {
      final String id = 'mood-${mood.name}';
      _success(
        await repository.create(
          domain.JournalEntry(
            id: id,
            origin: domain.JournalOrigin.manual,
            title: journalMoodLabel(mood),
            mood: mood,
            isPrivate: true,
            occurredAtUtc: now,
            createdAtUtc: now,
            updatedAtUtc: now,
            attachmentCount: 0,
          ),
        ),
      );
      expect(_success(await repository.findById(id))?.mood, mood);
    }
  });
}

T _success<T>(Result<T> result) => result.fold(
  onSuccess: (T value) => value,
  onFailure: (failure) => throw TestFailure(failure.message),
);
