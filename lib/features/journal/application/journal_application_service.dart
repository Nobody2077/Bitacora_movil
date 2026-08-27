import 'dart:math';

import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../domain/models/journal_entry.dart';
import '../domain/repositories/journal_repository.dart';

abstract interface class JournalClock {
  DateTime nowUtc();
}

final class SystemJournalClock implements JournalClock {
  const SystemJournalClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

abstract interface class JournalIdGenerator {
  String nextId();
}

final class SecureJournalIdGenerator implements JournalIdGenerator {
  SecureJournalIdGenerator() : _random = Random.secure();

  final Random _random;

  @override
  String nextId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

final class SaveJournalEntryRequest {
  const SaveJournalEntryRequest({
    required this.title,
    required this.isPrivate,
    required this.occurredAtUtc,
    this.existing,
    this.body,
    this.mood,
    this.origin = JournalOrigin.manual,
    this.missionId,
    this.transactionId,
  });

  final JournalEntry? existing;
  final String title;
  final String? body;
  final JournalMood? mood;
  final bool isPrivate;
  final DateTime occurredAtUtc;
  final JournalOrigin origin;
  final String? missionId;
  final String? transactionId;
}

final class JournalApplicationService {
  const JournalApplicationService({
    required JournalRepository repository,
    required JournalClock clock,
    required JournalIdGenerator idGenerator,
  }) : _repository = repository,
       _clock = clock,
       _idGenerator = idGenerator;

  final JournalRepository _repository;
  final JournalClock _clock;
  final JournalIdGenerator _idGenerator;

  Future<Result<JournalEntry>> save(SaveJournalEntryRequest request) {
    final String title = request.title.trim();
    final String? body = _trimmedOrNull(request.body);
    final JournalEntry? existing = request.existing;
    final JournalOrigin origin = existing?.origin ?? request.origin;
    final String? missionId =
        existing?.missionId ?? _trimmedOrNull(request.missionId);
    final String? transactionId =
        existing?.transactionId ?? _trimmedOrNull(request.transactionId);
    final AppFailure? failure = _validate(
      title: title,
      occurredAtUtc: request.occurredAtUtc,
      origin: origin,
      missionId: missionId,
      transactionId: transactionId,
      isNew: existing == null,
    );
    if (failure != null) {
      return Future<Result<JournalEntry>>.value(Failure<JournalEntry>(failure));
    }

    final DateTime nowUtc = _clock.nowUtc();
    final JournalEntry entry = JournalEntry(
      id: existing?.id ?? _idGenerator.nextId(),
      origin: origin,
      missionId: missionId,
      transactionId: transactionId,
      title: title,
      body: body,
      mood: request.mood,
      isPrivate: request.isPrivate,
      occurredAtUtc: request.occurredAtUtc,
      createdAtUtc: existing?.createdAtUtc ?? nowUtc,
      updatedAtUtc: nowUtc,
      attachmentCount: existing?.attachmentCount ?? 0,
    );
    return existing == null
        ? _repository.create(entry)
        : _repository.update(entry);
  }

  AppFailure? _validate({
    required String title,
    required DateTime occurredAtUtc,
    required JournalOrigin origin,
    required String? missionId,
    required String? transactionId,
    required bool isNew,
  }) {
    if (title.isEmpty || title.length > 160) {
      return const ValidationFailure(
        'El título debe tener entre 1 y 160 caracteres.',
      );
    }
    if (!occurredAtUtc.isUtc) {
      return const ValidationFailure('La fecha de la entrada no es válida.');
    }
    if (isNew && origin == JournalOrigin.system) {
      return const ValidationFailure(
        'Las entradas de sistema no se crean manualmente.',
      );
    }
    if (origin == JournalOrigin.mission &&
        (transactionId != null || isNew && missionId == null)) {
      return const ValidationFailure(
        'Selecciona una misión válida para vincular la entrada.',
      );
    }
    if (origin == JournalOrigin.transaction &&
        (missionId != null || isNew && transactionId == null)) {
      return const ValidationFailure(
        'Selecciona un movimiento válido para vincular la entrada.',
      );
    }
    if ((origin == JournalOrigin.manual || origin == JournalOrigin.system) &&
        (missionId != null || transactionId != null)) {
      return const ValidationFailure(
        'Una entrada manual no debe conservar vínculos de origen.',
      );
    }
    return null;
  }

  static String? _trimmedOrNull(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
