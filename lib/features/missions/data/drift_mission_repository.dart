import 'package:drift/drift.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../infrastructure/database/app_database.dart' as drift;
import '../../../infrastructure/database/daos/dao_support.dart';
import '../../../infrastructure/database/daos/mission_dao.dart';
import '../domain/models/mission.dart';
import '../domain/repositories/mission_repository.dart';
import 'mission_mapper.dart';

final class DriftMissionRepository implements MissionRepository {
  const DriftMissionRepository(this._dao);

  final MissionDao _dao;

  @override
  Future<Result<List<MissionArea>>> findVisibleAreas() async {
    try {
      final areas = await _dao.findVisibleAreas();
      return Success<List<MissionArea>>(
        areas
            .map(
              (area) => MissionArea(
                id: area.id,
                name: area.name,
                iconKey: area.iconKey,
                colorHex: area.colorHex,
                isDefault: area.isDefault == 1,
              ),
            )
            .toList(growable: false),
      );
    } on Object catch (error) {
      return Failure<List<MissionArea>>(
        StorageFailure('No se pudieron leer las áreas.', cause: error),
      );
    }
  }

  @override
  Future<Result<Mission?>> findById(String id) async {
    if (id.trim().isEmpty) {
      return const Failure<Mission?>(
        ValidationFailure('El identificador de misión es obligatorio.'),
      );
    }

    try {
      final aggregate = await _dao.getAggregate(id);
      return Success<Mission?>(
        MissionMapper.fromDrift(
          aggregate.mission,
          objectives: aggregate.objectives,
          timeEntries: aggregate.timeEntries,
        ),
      );
    } on RecordNotFoundException {
      return const Success<Mission?>(null);
    } on Object catch (error) {
      return Failure<Mission?>(
        StorageFailure('No se pudo leer la misión.', cause: error),
      );
    }
  }

  @override
  Future<Result<Mission?>> findActiveTimer() async {
    try {
      final aggregate = await _dao.findActiveTimerAggregate();
      return Success<Mission?>(
        aggregate == null
            ? null
            : MissionMapper.fromDrift(
                aggregate.mission,
                objectives: aggregate.objectives,
                timeEntries: aggregate.timeEntries,
              ),
      );
    } on Object catch (error) {
      return Failure<Mission?>(
        StorageFailure('No se pudo recuperar la misión activa.', cause: error),
      );
    }
  }

  @override
  Future<Result<List<Mission>>> findScheduledBetween({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    if (!startUtc.isUtc || !endUtc.isUtc || !endUtc.isAfter(startUtc)) {
      return const Failure<List<Mission>>(
        ValidationFailure(
          'El período de misiones debe usar límites UTC válidos.',
        ),
      );
    }

    try {
      final rows = await _dao
          .watchPeriod(
            startUtcMs: startUtc.millisecondsSinceEpoch,
            endUtcMs: endUtc.millisecondsSinceEpoch,
          )
          .first;
      return Success<List<Mission>>(
        rows.map(MissionMapper.fromDrift).toList(growable: false),
      );
    } on Object catch (error) {
      return Failure<List<Mission>>(
        StorageFailure('No se pudieron leer las misiones.', cause: error),
      );
    }
  }

  @override
  Stream<Result<List<Mission>>> watchScheduledBetween({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async* {
    if (!startUtc.isUtc || !endUtc.isUtc || !endUtc.isAfter(startUtc)) {
      yield const Failure<List<Mission>>(
        ValidationFailure(
          'El período de misiones debe usar límites UTC válidos.',
        ),
      );
      return;
    }

    try {
      await for (final rows in _dao.watchPeriod(
        startUtcMs: startUtc.millisecondsSinceEpoch,
        endUtcMs: endUtc.millisecondsSinceEpoch,
      )) {
        yield Success<List<Mission>>(
          rows.map(MissionMapper.fromDrift).toList(growable: false),
        );
      }
    } on Object catch (error) {
      yield Failure<List<Mission>>(
        StorageFailure('No se pudieron observar las misiones.', cause: error),
      );
    }
  }

  @override
  Stream<Result<List<Mission>>> watchUpcoming({
    required DateTime startUtc,
  }) async* {
    if (!startUtc.isUtc) {
      yield const Failure<List<Mission>>(
        ValidationFailure('El inicio de próximas misiones debe estar en UTC.'),
      );
      return;
    }
    try {
      await for (final rows in _dao.watchUpcoming(
        startUtcMs: startUtc.millisecondsSinceEpoch,
      )) {
        yield Success<List<Mission>>(
          rows.map(MissionMapper.fromDrift).toList(growable: false),
        );
      }
    } on Object catch (error) {
      yield Failure<List<Mission>>(
        StorageFailure(
          'No se pudieron observar las próximas misiones.',
          cause: error,
        ),
      );
    }
  }

  @override
  Stream<Result<List<Mission>>> watchAll() async* {
    try {
      await for (final rows in _dao.watchAll()) {
        yield Success<List<Mission>>(
          rows.map(MissionMapper.fromDrift).toList(growable: false),
        );
      }
    } on Object catch (error) {
      yield Failure<List<Mission>>(
        StorageFailure(
          'No se pudieron observar todas las misiones.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<Mission>> create(
    Mission mission, {
    required String eventId,
    required String notificationId,
    required DateTime occurredAtUtc,
  }) async {
    final ValidationFailure? invalid = _validateWrite(
      mission,
      eventId: eventId,
      occurredAtUtc: occurredAtUtc,
      requireExisting: false,
    );
    if (invalid != null) {
      return Failure<Mission>(invalid);
    }

    try {
      final startNotification = _startNotification(
        mission: mission,
        notificationId: notificationId,
        updatedAtUtc: occurredAtUtc,
      );
      final aggregate = await _dao.insertAggregate(
        mission: drift.MissionsCompanion.insert(
          id: mission.id,
          areaId: mission.areaId,
          title: mission.title.trim(),
          description: Value<String?>(_trimmedOrNull(mission.description)),
          missionType: _missionType(mission.type),
          importance: Value<String>(_importance(mission.importance)),
          priority: Value<String>(_priority(mission.priority)),
          difficulty: Value<String?>(_difficulty(mission.difficulty)),
          isRequired: mission.isRequired ? 1 : 0,
          status: _status(mission.status),
          scheduledAt: Value<int?>(_milliseconds(mission.scheduledAtUtc)),
          availableFrom: Value<int?>(_milliseconds(mission.availableFromUtc)),
          expiresAt: Value<int?>(_milliseconds(mission.expiresAtUtc)),
          estimatedMinutes: Value<int?>(mission.estimatedMinutes),
          budgetMinor: Value<int?>(mission.budgetMinor),
          xpPlanned: mission.xpPlanned,
        ),
        objectives: mission.objectives.map(
          (objective) => _objectiveCompanion(mission.id, objective),
        ),
        events: <drift.MissionEventsCompanion>[
          drift.MissionEventsCompanion.insert(
            id: eventId,
            missionId: mission.id,
            eventType: 'CREATED',
            toStatus: Value<String?>(_status(mission.status)),
            occurredAt: occurredAtUtc.millisecondsSinceEpoch,
          ),
        ],
        notifications: <drift.NotificationSchedulesCompanion>[
          ?startNotification,
        ],
      );
      return Success<Mission>(
        MissionMapper.fromDrift(
          aggregate.mission,
          objectives: aggregate.objectives,
          timeEntries: aggregate.timeEntries,
        ),
      );
    } on Object catch (error) {
      return Failure<Mission>(
        StorageFailure('No se pudo crear la misión.', cause: error),
      );
    }
  }

  @override
  Future<Result<Mission>> update(
    Mission mission, {
    required String eventId,
    required String notificationId,
    required DateTime occurredAtUtc,
  }) async {
    final ValidationFailure? invalid = _validateWrite(
      mission,
      eventId: eventId,
      occurredAtUtc: occurredAtUtc,
      requireExisting: true,
    );
    if (invalid != null) {
      return Failure<Mission>(invalid);
    }

    try {
      final startNotification = _startNotification(
        mission: mission,
        notificationId: notificationId,
        updatedAtUtc: occurredAtUtc,
      );
      final aggregate = await _dao.updateAggregate(
        missionId: mission.id,
        expectedRowVersion: mission.rowVersion,
        changes: drift.MissionsCompanion(
          areaId: Value<String>(mission.areaId),
          title: Value<String>(mission.title.trim()),
          description: Value<String?>(_trimmedOrNull(mission.description)),
          missionType: Value<String>(_missionType(mission.type)),
          importance: Value<String>(_importance(mission.importance)),
          priority: Value<String>(_priority(mission.priority)),
          difficulty: Value<String?>(_difficulty(mission.difficulty)),
          isRequired: Value<int>(mission.isRequired ? 1 : 0),
          status:
              const <MissionStatus>{
                MissionStatus.scheduled,
                MissionStatus.available,
              }.contains(mission.status)
              ? Value<String>(_status(mission.status))
              : const Value<String>.absent(),
          scheduledAt: Value<int?>(_milliseconds(mission.scheduledAtUtc)),
          availableFrom: Value<int?>(_milliseconds(mission.availableFromUtc)),
          expiresAt: Value<int?>(_milliseconds(mission.expiresAtUtc)),
          estimatedMinutes: Value<int?>(mission.estimatedMinutes),
          budgetMinor: Value<int?>(mission.budgetMinor),
          xpPlanned: Value<int>(mission.xpPlanned),
        ),
        objectives: mission.objectives.map(
          (objective) => _objectiveCompanion(mission.id, objective),
        ),
        event: drift.MissionEventsCompanion.insert(
          id: eventId,
          missionId: mission.id,
          eventType: 'UPDATED',
          fromStatus: Value<String?>(_status(mission.status)),
          toStatus: Value<String?>(_status(mission.status)),
          occurredAt: occurredAtUtc.millisecondsSinceEpoch,
        ),
        startNotification: startNotification,
        notificationUpdatedAtUtcMs: occurredAtUtc.millisecondsSinceEpoch,
      );
      return Success<Mission>(
        MissionMapper.fromDrift(
          aggregate.mission,
          objectives: aggregate.objectives,
          timeEntries: aggregate.timeEntries,
        ),
      );
    } on OptimisticLockException {
      return Failure<Mission>(
        ConflictFailure(
          'La misión cambió en otro proceso. Vuelve a abrirla antes de guardar.',
        ),
      );
    } on RecordNotFoundException {
      return const Failure<Mission>(
        ConflictFailure('La misión ya no está disponible.'),
      );
    } on Object catch (error) {
      return Failure<Mission>(
        StorageFailure('No se pudo actualizar la misión.', cause: error),
      );
    }
  }

  drift.NotificationSchedulesCompanion? _startNotification({
    required Mission mission,
    required String notificationId,
    required DateTime updatedAtUtc,
  }) {
    final DateTime? scheduledAt = mission.scheduledAtUtc;
    if (scheduledAt == null || !mission.hasScheduledTime) {
      return null;
    }
    final int nowMs = updatedAtUtc.millisecondsSinceEpoch;
    return drift.NotificationSchedulesCompanion.insert(
      id: notificationId,
      missionId: mission.id,
      notificationType: 'START',
      notifyAt: scheduledAt.millisecondsSinceEpoch,
      status: 'PENDING',
      createdAt: nowMs,
      updatedAt: nowMs,
    );
  }

  @override
  Future<Result<Mission>> startTimer({
    required String missionId,
    required int expectedRowVersion,
    required MissionStatus expectedStatus,
    required String timeEntryId,
    required String eventId,
    required DateTime occurredAtUtc,
  }) async {
    if (missionId.trim().isEmpty ||
        timeEntryId.trim().isEmpty ||
        eventId.trim().isEmpty ||
        expectedRowVersion < 1 ||
        !occurredAtUtc.isUtc ||
        !const <MissionStatus>{
          MissionStatus.scheduled,
          MissionStatus.available,
          MissionStatus.rescheduled,
          MissionStatus.paused,
        }.contains(expectedStatus)) {
      return const Failure<Mission>(
        ValidationFailure('No se puede iniciar esta misión.'),
      );
    }

    final String eventType = expectedStatus == MissionStatus.paused
        ? 'RESUMED'
        : 'STARTED';
    try {
      final aggregate = await _dao.startWorkTimer(
        missionId: missionId,
        expectedRowVersion: expectedRowVersion,
        expectedStatus: _status(expectedStatus),
        timeEntry: drift.TimeEntriesCompanion.insert(
          id: timeEntryId,
          missionId: missionId,
          source: 'TIMER',
          segmentType: 'WORK',
          startedAt: Value<int?>(occurredAtUtc.millisecondsSinceEpoch),
          durationSeconds: 0,
          createdAt: occurredAtUtc.millisecondsSinceEpoch,
        ),
        event: drift.MissionEventsCompanion.insert(
          id: eventId,
          missionId: missionId,
          eventType: eventType,
          fromStatus: Value<String?>(_status(expectedStatus)),
          toStatus: const Value<String?>('ACTIVE'),
          occurredAt: occurredAtUtc.millisecondsSinceEpoch,
        ),
      );
      return Success<Mission>(
        MissionMapper.fromDrift(
          aggregate.mission,
          objectives: aggregate.objectives,
          timeEntries: aggregate.timeEntries,
        ),
      );
    } on ActiveTimerConflictException catch (error) {
      return Failure<Mission>(
        ActiveTimerFailure(activeMissionId: error.activeMissionId),
      );
    } on OptimisticLockException {
      return Failure<Mission>(
        ConflictFailure(
          'La misión cambió antes de iniciar el cronómetro. Vuelve a abrirla.',
        ),
      );
    } on Object catch (error) {
      return Failure<Mission>(
        StorageFailure('No se pudo iniciar el cronómetro.', cause: error),
      );
    }
  }

  @override
  Future<Result<Mission>> pauseTimer({
    required String missionId,
    required int expectedRowVersion,
    required String eventId,
    required DateTime occurredAtUtc,
  }) async {
    if (missionId.trim().isEmpty ||
        eventId.trim().isEmpty ||
        expectedRowVersion < 1 ||
        !occurredAtUtc.isUtc) {
      return const Failure<Mission>(
        ValidationFailure('No se puede pausar esta misión.'),
      );
    }

    try {
      final aggregate = await _dao.pauseWorkTimer(
        missionId: missionId,
        expectedRowVersion: expectedRowVersion,
        occurredAtUtcMs: occurredAtUtc.millisecondsSinceEpoch,
        event: drift.MissionEventsCompanion.insert(
          id: eventId,
          missionId: missionId,
          eventType: 'PAUSED',
          fromStatus: const Value<String?>('ACTIVE'),
          toStatus: const Value<String?>('PAUSED'),
          occurredAt: occurredAtUtc.millisecondsSinceEpoch,
        ),
      );
      return Success<Mission>(
        MissionMapper.fromDrift(
          aggregate.mission,
          objectives: aggregate.objectives,
          timeEntries: aggregate.timeEntries,
        ),
      );
    } on OptimisticLockException {
      return Failure<Mission>(
        ConflictFailure(
          'La misión cambió antes de pausar el cronómetro. Vuelve a abrirla.',
        ),
      );
    } on DatabaseInvariantException {
      return Failure<Mission>(
        ConflictFailure('No existe un cronómetro abierto para esta misión.'),
      );
    } on Object catch (error) {
      return Failure<Mission>(
        StorageFailure('No se pudo pausar el cronómetro.', cause: error),
      );
    }
  }

  @override
  Future<Result<Mission>> switchTimer({
    required Mission activeMission,
    required Mission targetMission,
    required String pauseEventId,
    required String timeEntryId,
    required String startEventId,
    required DateTime occurredAtUtc,
  }) async {
    if (activeMission.id == targetMission.id ||
        activeMission.status != MissionStatus.active ||
        !const <MissionStatus>{
          MissionStatus.scheduled,
          MissionStatus.available,
          MissionStatus.paused,
          MissionStatus.rescheduled,
        }.contains(targetMission.status) ||
        !occurredAtUtc.isUtc) {
      return const Failure<Mission>(
        ValidationFailure('No se puede cambiar a esta misión.'),
      );
    }
    final int occurredAtMs = occurredAtUtc.millisecondsSinceEpoch;
    final String startEventType = targetMission.status == MissionStatus.paused
        ? 'RESUMED'
        : 'STARTED';
    try {
      final aggregate = await _dao.switchWorkTimer(
        activeMissionId: activeMission.id,
        activeRowVersion: activeMission.rowVersion,
        pauseEvent: drift.MissionEventsCompanion.insert(
          id: pauseEventId,
          missionId: activeMission.id,
          eventType: 'PAUSED',
          fromStatus: const Value<String?>('ACTIVE'),
          toStatus: const Value<String?>('PAUSED'),
          occurredAt: occurredAtMs,
        ),
        occurredAtUtcMs: occurredAtMs,
        targetMissionId: targetMission.id,
        targetRowVersion: targetMission.rowVersion,
        targetStatus: _status(targetMission.status),
        targetTimeEntry: drift.TimeEntriesCompanion.insert(
          id: timeEntryId,
          missionId: targetMission.id,
          source: 'TIMER',
          segmentType: 'WORK',
          startedAt: Value<int?>(occurredAtMs),
          durationSeconds: 0,
          createdAt: occurredAtMs,
        ),
        startEvent: drift.MissionEventsCompanion.insert(
          id: startEventId,
          missionId: targetMission.id,
          eventType: startEventType,
          fromStatus: Value<String?>(_status(targetMission.status)),
          toStatus: const Value<String?>('ACTIVE'),
          occurredAt: occurredAtMs,
        ),
      );
      return Success<Mission>(
        MissionMapper.fromDrift(
          aggregate.mission,
          objectives: aggregate.objectives,
          timeEntries: aggregate.timeEntries,
        ),
      );
    } on OptimisticLockException {
      return const Failure<Mission>(
        ConflictFailure(
          'Una de las misiones cambió. Vuelve a abrir el cambio de cronómetro.',
        ),
      );
    } on DatabaseInvariantException {
      return const Failure<Mission>(
        ConflictFailure('El cronómetro activo cambió antes de confirmar.'),
      );
    } on Object catch (error) {
      return Failure<Mission>(
        StorageFailure('No se pudo cambiar el cronómetro.', cause: error),
      );
    }
  }

  @override
  Future<Result<Mission>> archive({
    required Mission mission,
    required String eventId,
    required DateTime occurredAtUtc,
  }) async {
    if (mission.id.trim().isEmpty ||
        eventId.trim().isEmpty ||
        mission.rowVersion < 1 ||
        mission.archivedAtUtc != null ||
        mission.status == MissionStatus.active ||
        mission.openWorkTimer != null ||
        !occurredAtUtc.isUtc) {
      return const Failure<Mission>(
        ValidationFailure('Esta misión no se puede archivar.'),
      );
    }
    try {
      final aggregate = await _dao.archiveAggregate(
        missionId: mission.id,
        expectedRowVersion: mission.rowVersion,
        archivedAtUtcMs: occurredAtUtc.millisecondsSinceEpoch,
        event: drift.MissionEventsCompanion.insert(
          id: eventId,
          missionId: mission.id,
          eventType: 'ARCHIVED',
          fromStatus: Value<String?>(_status(mission.status)),
          toStatus: Value<String?>(_status(mission.status)),
          occurredAt: occurredAtUtc.millisecondsSinceEpoch,
        ),
      );
      return Success<Mission>(
        MissionMapper.fromDrift(
          aggregate.mission,
          objectives: aggregate.objectives,
          timeEntries: aggregate.timeEntries,
        ),
      );
    } on OptimisticLockException {
      return const Failure<Mission>(
        ConflictFailure(
          'La misión cambió antes de archivarse. Vuelve a abrirla.',
        ),
      );
    } on DatabaseInvariantException {
      return const Failure<Mission>(
        ConflictFailure('La misión ya no se puede archivar.'),
      );
    } on RecordNotFoundException {
      return const Failure<Mission>(
        ConflictFailure('La misión ya no está disponible.'),
      );
    } on Object catch (error) {
      return Failure<Mission>(
        StorageFailure('No se pudo archivar la misión.', cause: error),
      );
    }
  }

  drift.MissionObjectivesCompanion _objectiveCompanion(
    String missionId,
    MissionObjective objective,
  ) => drift.MissionObjectivesCompanion.insert(
    id: objective.id,
    missionId: missionId,
    description: objective.description.trim(),
    position: objective.position,
    completedAt: Value<int?>(_milliseconds(objective.completedAtUtc)),
    createdAt: objective.createdAtUtc.millisecondsSinceEpoch,
  );

  ValidationFailure? _validateWrite(
    Mission mission, {
    required String eventId,
    required DateTime occurredAtUtc,
    required bool requireExisting,
  }) {
    if (mission.id.trim().isEmpty ||
        eventId.trim().isEmpty ||
        mission.areaId.trim().isEmpty ||
        mission.title.trim().isEmpty ||
        mission.title.trim().length > 160 ||
        !occurredAtUtc.isUtc ||
        mission.scheduledAtUtc?.isUtc == false ||
        mission.availableFromUtc?.isUtc == false ||
        mission.expiresAtUtc?.isUtc == false ||
        (mission.availableFromUtc != null &&
            mission.scheduledAtUtc != null &&
            mission.availableFromUtc!.isAfter(mission.scheduledAtUtc!)) ||
        (mission.scheduledAtUtc != null &&
            mission.expiresAtUtc != null &&
            mission.scheduledAtUtc!.isAfter(mission.expiresAtUtc!)) ||
        (mission.availableFromUtc != null &&
            mission.expiresAtUtc != null &&
            mission.availableFromUtc!.isAfter(mission.expiresAtUtc!)) ||
        mission.xpPlanned < 0 ||
        (mission.estimatedMinutes != null && mission.estimatedMinutes! <= 0) ||
        (mission.budgetMinor != null && mission.budgetMinor! < 0) ||
        (requireExisting && mission.rowVersion < 1)) {
      return const ValidationFailure(
        'La misión contiene datos obligatorios o valores inválidos.',
      );
    }
    for (var index = 0; index < mission.objectives.length; index++) {
      final objective = mission.objectives[index];
      final description = objective.description.trim();
      if (objective.id.trim().isEmpty ||
          description.isEmpty ||
          description.length > 240 ||
          objective.position != index ||
          !objective.createdAtUtc.isUtc ||
          objective.completedAtUtc?.isUtc == false) {
        return const ValidationFailure(
          'Los objetivos de la misión contienen valores inválidos.',
        );
      }
    }
    return null;
  }

  static String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static int? _milliseconds(DateTime? value) => value?.millisecondsSinceEpoch;

  static String _missionType(MissionType value) => switch (value) {
    MissionType.primary => 'PRIMARY',
    MissionType.secondary => 'SECONDARY',
    MissionType.errand => 'ERRAND',
    MissionType.daily => 'DAILY',
    MissionType.recurring => 'RECURRING',
    MissionType.event => 'EVENT',
    MissionType.challenge => 'CHALLENGE',
    MissionType.custom => 'CUSTOM',
  };

  static String _importance(MissionImportance value) => switch (value) {
    MissionImportance.minor => 'MINOR',
    MissionImportance.normal => 'NORMAL',
    MissionImportance.important => 'IMPORTANT',
    MissionImportance.veryImportant => 'VERY_IMPORTANT',
    MissionImportance.critical => 'CRITICAL',
  };

  static String _priority(MissionPriority value) => switch (value) {
    MissionPriority.low => 'LOW',
    MissionPriority.normal => 'NORMAL',
    MissionPriority.high => 'HIGH',
    MissionPriority.urgent => 'URGENT',
  };

  static String? _difficulty(MissionDifficulty? value) => switch (value) {
    null => null,
    MissionDifficulty.easy => 'EASY',
    MissionDifficulty.medium => 'MEDIUM',
    MissionDifficulty.hard => 'HARD',
  };

  static String _status(MissionStatus value) => switch (value) {
    MissionStatus.draft => 'DRAFT',
    MissionStatus.scheduled => 'SCHEDULED',
    MissionStatus.available => 'AVAILABLE',
    MissionStatus.active => 'ACTIVE',
    MissionStatus.paused => 'PAUSED',
    MissionStatus.rescheduled => 'RESCHEDULED',
    MissionStatus.expired => 'EXPIRED',
    MissionStatus.abandoned => 'ABANDONED',
    MissionStatus.cancelled => 'CANCELLED',
    MissionStatus.partial => 'PARTIAL',
    MissionStatus.completed => 'COMPLETED',
  };
}
