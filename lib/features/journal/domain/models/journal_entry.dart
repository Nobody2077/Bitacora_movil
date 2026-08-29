enum JournalOrigin { manual, mission, transaction, system }

enum JournalMood {
  happy,
  motivated,
  focused,
  calm,
  normal,
  anxious,
  sad,
  tired,
}

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
    this.archivedAtUtc,
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
  final DateTime? archivedAtUtc;

  bool get isLinked => missionId != null || transactionId != null;
  bool get isArchived => archivedAtUtc != null;

  JournalEntry copyWith({
    String? title,
    String? body,
    JournalMood? mood,
    bool? isPrivate,
    DateTime? occurredAtUtc,
    DateTime? updatedAtUtc,
  }) => JournalEntry(
    id: id,
    origin: origin,
    missionId: missionId,
    transactionId: transactionId,
    title: title ?? this.title,
    body: body,
    mood: mood,
    isPrivate: isPrivate ?? this.isPrivate,
    occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
    createdAtUtc: createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    attachmentCount: attachmentCount,
    archivedAtUtc: archivedAtUtc,
  );
}

final class JournalSearchCriteria {
  JournalSearchCriteria({
    required this.startUtc,
    required this.endUtc,
    this.query = '',
    Set<JournalOrigin> origins = const <JournalOrigin>{},
    this.withPhotosOnly = false,
    this.limit = 200,
  }) : origins = Set<JournalOrigin>.unmodifiable(origins);

  final DateTime startUtc;
  final DateTime endUtc;
  final String query;
  final Set<JournalOrigin> origins;
  final bool withPhotosOnly;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is JournalSearchCriteria &&
      startUtc == other.startUtc &&
      endUtc == other.endUtc &&
      query == other.query &&
      _sameOrigins(origins, other.origins) &&
      withPhotosOnly == other.withPhotosOnly &&
      limit == other.limit;

  @override
  int get hashCode => Object.hash(
    startUtc,
    endUtc,
    query,
    Object.hashAllUnordered(origins),
    withPhotosOnly,
    limit,
  );

  static bool _sameOrigins(Set<JournalOrigin> left, Set<JournalOrigin> right) =>
      left.length == right.length && left.containsAll(right);
}
