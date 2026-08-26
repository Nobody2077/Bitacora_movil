import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../app/application/commands/complete_mission.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../features/missions/data/mission_mapper.dart';
import '../../../features/missions/domain/models/mission.dart' as domain;
import '../app_database.dart';
import '../daos/dao_support.dart';

final class DriftCompleteMissionUnitOfWork
    implements CompleteMissionUnitOfWork {
  const DriftCompleteMissionUnitOfWork(this._database);

  final AppDatabase _database;

  @override
  Future<Result<MissionCompletionReceipt>> complete(
    CompleteMissionOperation operation,
  ) async {
    try {
      final MissionCompletionReceipt receipt = await _database.transaction(
        () => _complete(operation),
      );
      return Success<MissionCompletionReceipt>(receipt);
    } on OptimisticLockException {
      return const Failure<MissionCompletionReceipt>(
        ConflictFailure(
          'La misión cambió antes de completarse. Vuelve a abrir la revisión.',
        ),
      );
    } on RecordNotFoundException {
      return const Failure<MissionCompletionReceipt>(
        ConflictFailure('La misión ya no está disponible.'),
      );
    } on DatabaseInvariantException {
      return const Failure<MissionCompletionReceipt>(
        ConflictFailure(
          'Los datos de ejecución cambiaron. Vuelve a abrir la misión.',
        ),
      );
    } on Object catch (error) {
      return Failure<MissionCompletionReceipt>(
        StorageFailure('No se pudo completar la misión.', cause: error),
      );
    }
  }

  Future<MissionCompletionReceipt> _complete(
    CompleteMissionOperation operation,
  ) async {
    final CompleteMissionRequest request = operation.request;
    final domain.Mission expected = request.mission;
    final Mission? current = await (_database.select(
      _database.missions,
    )..where((table) => table.id.equals(expected.id))).getSingleOrNull();
    if (current == null) {
      throw RecordNotFoundException(table: 'missions', key: expected.id);
    }
    if (current.rowVersion != expected.rowVersion ||
        current.status != _missionStatus(expected.status)) {
      throw OptimisticLockException(
        table: 'missions',
        id: expected.id,
        expectedRowVersion: expected.rowVersion,
      );
    }

    final List<TimeEntry> openTimers =
        await (_database.select(_database.timeEntries)..where(
              (table) =>
                  table.missionId.equals(expected.id) &
                  table.source.equals('TIMER') &
                  table.segmentType.equals('WORK') &
                  table.endedAt.isNull(),
            ))
            .get();
    if ((current.status == 'ACTIVE' && openTimers.length != 1) ||
        (current.status != 'ACTIVE' && openTimers.isNotEmpty)) {
      throw const DatabaseInvariantException(
        'Mission status and open timer are inconsistent.',
      );
    }
    final int occurredAtMs = operation.occurredAtUtc.millisecondsSinceEpoch;
    if (openTimers.isNotEmpty) {
      final TimeEntry openTimer = openTimers.single;
      final int? startedAt = openTimer.startedAt;
      if (startedAt == null) {
        throw const DatabaseInvariantException(
          'An open TIMER/WORK entry requires started_at.',
        );
      }
      final int safeEndedAt = occurredAtMs < startedAt
          ? startedAt
          : occurredAtMs;
      final int closed =
          await (_database.update(_database.timeEntries)..where(
                (table) =>
                    table.id.equals(openTimer.id) & table.endedAt.isNull(),
              ))
              .write(
                TimeEntriesCompanion(
                  endedAt: Value<int?>(safeEndedAt),
                  durationSeconds: Value<int>(
                    (safeEndedAt - startedAt) ~/ 1000,
                  ),
                ),
              );
      if (closed != 1) {
        throw OptimisticLockException(
          table: 'time_entries',
          id: openTimer.id,
          expectedRowVersion: expected.rowVersion,
        );
      }
    }

    final List<MissionObjective> objectives = await (_database.select(
      _database.missionObjectives,
    )..where((table) => table.missionId.equals(expected.id))).get();
    final Set<String> persistedObjectiveIds = objectives
        .map((objective) => objective.id)
        .toSet();
    if (!persistedObjectiveIds.containsAll(request.completedObjectiveIds) ||
        (request.outcome == MissionCompletionOutcome.completed &&
            persistedObjectiveIds.length !=
                request.completedObjectiveIds.length)) {
      throw const DatabaseInvariantException(
        'Objective selection no longer matches the mission.',
      );
    }
    for (final objective in objectives) {
      await (_database.update(
        _database.missionObjectives,
      )..where((table) => table.id.equals(objective.id))).write(
        MissionObjectivesCompanion(
          completedAt: Value<int?>(
            request.completedObjectiveIds.contains(objective.id)
                ? occurredAtMs
                : null,
          ),
        ),
      );
    }

    final String targetStatus =
        request.outcome == MissionCompletionOutcome.completed
        ? 'COMPLETED'
        : 'PARTIAL';
    final int affected =
        await (_database.update(_database.missions)..where(
              (table) =>
                  table.id.equals(expected.id) &
                  table.rowVersion.equals(expected.rowVersion) &
                  table.status.equals(current.status),
            ))
            .write(
              MissionsCompanion(
                status: Value<String>(targetStatus),
                actualResult: Value<String>(request.actualResult.trim()),
                convenienceRating: Value<String?>(
                  _convenienceRating(request.convenienceRating),
                ),
                completedAt: Value<int?>(occurredAtMs),
                rowVersion: Value<int>(expected.rowVersion + 1),
              ),
            );
    if (affected != 1) {
      throw OptimisticLockException(
        table: 'missions',
        id: expected.id,
        expectedRowVersion: expected.rowVersion,
      );
    }

    String? movementTransactionId;
    if (request.movementMinor != null) {
      movementTransactionId = operation.movementTransactionId;
      await _database
          .into(_database.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: movementTransactionId,
              operationId: operation.movementOperationId,
              missionId: Value<String?>(expected.id),
              transactionType:
                  request.movementType == CompletionMovementType.expense
                  ? 'EXPENSE'
                  : 'INCOME',
              amountMinor: request.movementMinor!,
              paymentMethod: Value<String?>(
                _paymentMethod(request.paymentMethod!),
              ),
              category: Value<String?>(
                _trimmedOrNull(request.movementCategory),
              ),
              note: const Value<String?>(
                'Movimiento registrado durante el cierre de misión.',
              ),
              occurredAt: occurredAtMs,
              createdAt: occurredAtMs,
            ),
          );
    }

    await _database
        .into(_database.journalEntries)
        .insert(
          JournalEntriesCompanion.insert(
            id: operation.journalEntryId,
            originType: 'MISSION',
            missionId: Value<String?>(expected.id),
            transactionId: Value<String?>(movementTransactionId),
            title: current.title,
            body: Value<String?>(_journalBody(request)),
            isPrivate: 1,
            occurredAt: occurredAtMs,
            createdAt: occurredAtMs,
            updatedAt: occurredAtMs,
          ),
        );

    final int xpAwarded = request.outcome == MissionCompletionOutcome.completed
        ? current.xpPlanned
        : 0;
    if (xpAwarded > 0) {
      await _database
          .into(_database.xpTransactions)
          .insert(
            XpTransactionsCompanion.insert(
              id: operation.xpTransactionId,
              areaId: current.areaId,
              missionId: Value<String?>(expected.id),
              journalEntryId: Value<String?>(operation.journalEntryId),
              sourceType: 'MISSION',
              amount: xpAwarded,
              reason: const Value<String?>('Misión completada'),
              occurredAt: occurredAtMs,
            ),
          );
    }

    await _database
        .into(_database.missionEvents)
        .insert(
          MissionEventsCompanion.insert(
            id: operation.eventId,
            missionId: expected.id,
            eventType: request.outcome == MissionCompletionOutcome.completed
                ? 'COMPLETED'
                : 'PARTIALLY_COMPLETED',
            fromStatus: Value<String?>(current.status),
            toStatus: Value<String?>(targetStatus),
            snapshotJson: Value<String?>(
              jsonEncode(<String, Object?>{
                'importance': current.importance,
                'xp_planned': current.xpPlanned,
                'xp_awarded': xpAwarded,
                'budget_minor': current.budgetMinor,
                'movement_type': request.movementMinor == null
                    ? null
                    : request.movementType.name,
                'movement_minor': request.movementMinor,
              }),
            ),
            occurredAt: occurredAtMs,
          ),
        );

    await (_database.update(_database.notificationSchedules)..where(
          (table) =>
              table.missionId.equals(expected.id) &
              table.status.isIn(const <String>{'PENDING', 'SCHEDULED'}),
        ))
        .write(
          NotificationSchedulesCompanion(
            status: const Value<String>('CANCELLED'),
            updatedAt: Value<int>(occurredAtMs),
          ),
        );

    final domain.Mission completedMission = await _readMission(expected.id);
    return MissionCompletionReceipt(
      mission: completedMission,
      xpAwarded: xpAwarded,
      totalWorkSeconds: completedMission.elapsedWorkSecondsAt(
        operation.occurredAtUtc,
      ),
      journalEntryId: operation.journalEntryId,
      movementMinor: request.movementMinor,
      movementType: request.movementMinor == null ? null : request.movementType,
    );
  }

  @override
  Future<Result<MissionCompletionReceipt?>> findReceipt(
    String missionId,
  ) async {
    if (missionId.trim().isEmpty) {
      return const Failure<MissionCompletionReceipt?>(
        ValidationFailure('El identificador de misión es obligatorio.'),
      );
    }
    try {
      final domain.Mission mission = await _readMission(missionId);
      if (!const <domain.MissionStatus>{
        domain.MissionStatus.completed,
        domain.MissionStatus.partial,
      }.contains(mission.status)) {
        return const Success<MissionCompletionReceipt?>(null);
      }
      final XpTransaction? xp =
          await (_database.select(_database.xpTransactions)..where(
                (table) =>
                    table.missionId.equals(missionId) &
                    table.sourceType.equals('MISSION'),
              ))
              .getSingleOrNull();
      final JournalEntry? journal =
          await (_database.select(_database.journalEntries)
                ..where(
                  (table) =>
                      table.missionId.equals(missionId) &
                      table.originType.equals('MISSION'),
                )
                ..orderBy(<OrderingTerm Function(JournalEntries)>[
                  (table) => OrderingTerm.desc(table.occurredAt),
                  (table) => OrderingTerm.desc(table.id),
                ])
                ..limit(1))
              .getSingleOrNull();
      final Transaction? movement = journal?.transactionId == null
          ? null
          : await (_database.select(_database.transactions)
                  ..where((table) => table.id.equals(journal!.transactionId!)))
                .getSingleOrNull();
      final DateTime completedAtUtc =
          mission.completedAtUtc ?? DateTime.now().toUtc();
      return Success<MissionCompletionReceipt?>(
        MissionCompletionReceipt(
          mission: mission,
          xpAwarded: xp?.amount ?? 0,
          totalWorkSeconds: mission.elapsedWorkSecondsAt(completedAtUtc),
          journalEntryId: journal?.id,
          movementMinor: movement?.amountMinor,
          movementType: switch (movement?.transactionType) {
            'EXPENSE' => CompletionMovementType.expense,
            'INCOME' => CompletionMovementType.income,
            _ => null,
          },
        ),
      );
    } on RecordNotFoundException {
      return const Success<MissionCompletionReceipt?>(null);
    } on Object catch (error) {
      return Failure<MissionCompletionReceipt?>(
        StorageFailure(
          'No se pudo leer el resultado de la misión.',
          cause: error,
        ),
      );
    }
  }

  Future<domain.Mission> _readMission(String missionId) async {
    final Mission? mission = await (_database.select(
      _database.missions,
    )..where((table) => table.id.equals(missionId))).getSingleOrNull();
    if (mission == null) {
      throw RecordNotFoundException(table: 'missions', key: missionId);
    }
    final objectives =
        await (_database.select(_database.missionObjectives)
              ..where((table) => table.missionId.equals(missionId))
              ..orderBy(<OrderingTerm Function(MissionObjectives)>[
                (table) => OrderingTerm.asc(table.position),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    final timeEntries =
        await (_database.select(_database.timeEntries)
              ..where((table) => table.missionId.equals(missionId))
              ..orderBy(<OrderingTerm Function(TimeEntries)>[
                (table) => OrderingTerm.asc(table.startedAt),
                (table) => OrderingTerm.asc(table.createdAt),
              ]))
            .get();
    return MissionMapper.fromDrift(
      mission,
      objectives: objectives,
      timeEntries: timeEntries,
    );
  }

  static String _missionStatus(domain.MissionStatus value) => switch (value) {
    domain.MissionStatus.draft => 'DRAFT',
    domain.MissionStatus.scheduled => 'SCHEDULED',
    domain.MissionStatus.available => 'AVAILABLE',
    domain.MissionStatus.active => 'ACTIVE',
    domain.MissionStatus.paused => 'PAUSED',
    domain.MissionStatus.rescheduled => 'RESCHEDULED',
    domain.MissionStatus.expired => 'EXPIRED',
    domain.MissionStatus.abandoned => 'ABANDONED',
    domain.MissionStatus.cancelled => 'CANCELLED',
    domain.MissionStatus.partial => 'PARTIAL',
    domain.MissionStatus.completed => 'COMPLETED',
  };

  static String? _convenienceRating(domain.ConvenienceRating? value) =>
      switch (value) {
        null => null,
        domain.ConvenienceRating.totallyWorthIt => 'TOTALLY_WORTH_IT',
        domain.ConvenienceRating.worthItButCostly => 'WORTH_IT_BUT_COSTLY',
        domain.ConvenienceRating.partiallyWorthIt => 'PARTIALLY_WORTH_IT',
        domain.ConvenienceRating.barelyWorthIt => 'BARELY_WORTH_IT',
        domain.ConvenienceRating.wouldNotRepeat => 'WOULD_NOT_REPEAT',
      };

  static String _paymentMethod(CompletionPaymentMethod value) =>
      switch (value) {
        CompletionPaymentMethod.cash => 'CASH',
        CompletionPaymentMethod.bank => 'BANK',
        CompletionPaymentMethod.wallet => 'WALLET',
      };

  static String _journalBody(CompleteMissionRequest request) {
    final String result = request.actualResult.trim();
    final String? note = _trimmedOrNull(request.journalNote);
    return note == null ? result : '$result\n\n$note';
  }

  static String? _trimmedOrNull(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
