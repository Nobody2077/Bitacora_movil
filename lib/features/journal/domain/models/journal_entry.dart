enum JournalOrigin { manual, mission, transaction, system }

enum JournalMood { focused, normal, tired }

/// Entrada de Bitácora sin dependencias de almacenamiento o presentación.
final class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.origin,
    required this.title,
    required this.isPrivate,
    required this.occurredAtUtc,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.attachmentCount,
    this.missionId,
    this.transactionId,
    this.body,
    this.mood,
  });

  final String id;
  final JournalOrigin origin;
  final String? missionId;
  final String? transactionId;
  final String title;
  final String? body;
  final JournalMood? mood;
  final bool isPrivate;
  final DateTime occurredAtUtc;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final int attachmentCount;
}
