import 'package:drift/drift.dart';

import '../../../infrastructure/database/app_database.dart' as drift;
import '../domain/models/journal_entry.dart';

abstract final class JournalMapper {
  static JournalEntry fromDrift(
    drift.JournalEntry value, {
    required int attachmentCount,
  }) => JournalEntry(
    id: value.id,
    origin: _origin(value.originType),
    missionId: value.missionId,
    transactionId: value.transactionId,
    title: value.title,
    body: value.body,
    mood: _mood(value.moodDetail ?? value.mood),
    isPrivate: value.isPrivate == 1,
    occurredAtUtc: _utc(value.occurredAt),
    createdAtUtc: _utc(value.createdAt),
    updatedAtUtc: _utc(value.updatedAt),
    attachmentCount: attachmentCount,
    archivedAtUtc: value.archivedAt == null ? null : _utc(value.archivedAt!),
  );

  static DateTime _utc(int milliseconds) =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);

  static drift.JournalEntriesCompanion toInsert(JournalEntry value) =>
      drift.JournalEntriesCompanion.insert(
        id: value.id,
        originType: _originToDrift(value.origin),
        missionId: Value<String?>(value.missionId),
        transactionId: Value<String?>(value.transactionId),
        title: value.title,
        body: Value<String?>(value.body),
        mood: Value<String?>(_legacyMoodToDrift(value.mood)),
        moodDetail: Value<String?>(_moodToDrift(value.mood)),
        isPrivate: value.isPrivate ? 1 : 0,
        occurredAt: value.occurredAtUtc.millisecondsSinceEpoch,
        createdAt: value.createdAtUtc.millisecondsSinceEpoch,
        updatedAt: value.updatedAtUtc.millisecondsSinceEpoch,
      );

  static drift.JournalEntriesCompanion toUpdate(JournalEntry value) =>
      drift.JournalEntriesCompanion(
        title: Value<String>(value.title),
        body: Value<String?>(value.body),
        mood: Value<String?>(_legacyMoodToDrift(value.mood)),
        moodDetail: Value<String?>(_moodToDrift(value.mood)),
        isPrivate: Value<int>(value.isPrivate ? 1 : 0),
        occurredAt: Value<int>(value.occurredAtUtc.millisecondsSinceEpoch),
        updatedAt: Value<int>(value.updatedAtUtc.millisecondsSinceEpoch),
      );

  static JournalOrigin _origin(String value) => switch (value) {
    'MANUAL' => JournalOrigin.manual,
    'MISSION' => JournalOrigin.mission,
    'TRANSACTION' => JournalOrigin.transaction,
    'SYSTEM' => JournalOrigin.system,
    _ => throw FormatException('Unknown persisted journal origin: $value'),
  };

  static JournalMood? _mood(String? value) => switch (value) {
    null => null,
    'HAPPY' => JournalMood.happy,
    'MOTIVATED' => JournalMood.motivated,
    'FOCUSED' => JournalMood.focused,
    'CALM' => JournalMood.calm,
    'NORMAL' => JournalMood.normal,
    'ANXIOUS' => JournalMood.anxious,
    'SAD' => JournalMood.sad,
    'TIRED' => JournalMood.tired,
    _ => throw FormatException('Unknown persisted journal mood: $value'),
  };

  static String _originToDrift(JournalOrigin value) => switch (value) {
    JournalOrigin.manual => 'MANUAL',
    JournalOrigin.mission => 'MISSION',
    JournalOrigin.transaction => 'TRANSACTION',
    JournalOrigin.system => 'SYSTEM',
  };

  static String? _moodToDrift(JournalMood? value) => switch (value) {
    null => null,
    JournalMood.happy => 'HAPPY',
    JournalMood.motivated => 'MOTIVATED',
    JournalMood.focused => 'FOCUSED',
    JournalMood.calm => 'CALM',
    JournalMood.normal => 'NORMAL',
    JournalMood.anxious => 'ANXIOUS',
    JournalMood.sad => 'SAD',
    JournalMood.tired => 'TIRED',
  };

  static String? _legacyMoodToDrift(JournalMood? value) => switch (value) {
    JournalMood.focused => 'FOCUSED',
    JournalMood.normal => 'NORMAL',
    JournalMood.tired => 'TIRED',
    _ => null,
  };
}
