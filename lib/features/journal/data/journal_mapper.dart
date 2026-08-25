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
    mood: _mood(value.mood),
    isPrivate: value.isPrivate == 1,
    occurredAtUtc: _utc(value.occurredAt),
    createdAtUtc: _utc(value.createdAt),
    updatedAtUtc: _utc(value.updatedAt),
    attachmentCount: attachmentCount,
  );

  static DateTime _utc(int milliseconds) =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);

  static JournalOrigin _origin(String value) => switch (value) {
    'MANUAL' => JournalOrigin.manual,
    'MISSION' => JournalOrigin.mission,
    'TRANSACTION' => JournalOrigin.transaction,
    'SYSTEM' => JournalOrigin.system,
    _ => throw FormatException('Unknown persisted journal origin: $value'),
  };

  static JournalMood? _mood(String? value) => switch (value) {
    null => null,
    'FOCUSED' => JournalMood.focused,
    'NORMAL' => JournalMood.normal,
    'TIRED' => JournalMood.tired,
    _ => throw FormatException('Unknown persisted journal mood: $value'),
  };
}
