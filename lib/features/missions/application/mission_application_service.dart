import 'dart:math';

import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../domain/models/mission.dart';
import '../domain/repositories/mission_repository.dart';

abstract interface class MissionClock {
  DateTime nowUtc();
}

final class SystemMissionClock implements MissionClock {
  const SystemMissionClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

abstract interface class MissionIdGenerator {
  String nextId();
}

final class SecureMissionIdGenerator implements MissionIdGenerator {
  SecureMissionIdGenerator() : _random = Random.secure();

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

final class MissionObjectiveDraft {
  const MissionObjectiveDraft({
    required this.description,
    this.id,
    this.createdAtUtc,
    this.completedAtUtc,
  });

  final String? id;
  final String description;
  final DateTime? createdAtUtc;
  final DateTime? completedAtUtc;
}

final class SaveMissionRequest {
  const SaveMissionRequest({
    required this.areaId,
    required this.title,
    required this.type,
    required this.importance,
    required this.priority,
    required this.isRequired,
    required this.xpPlanned,
    required this.objectives,
    this.existing,
    this.description,
    this.difficulty,
    this.scheduledAtUtc,
    this.availableFromUtc,
    this.expiresAtUtc,
    this.estimatedMinutes,
    this.budgetMinor,
    this.location,
    this.contactIds,
  });

  final Mission? existing;
  final String areaId;
  final String title;
  final String? description;
  final String? location;

  /// Personajes de la misión. `null` al editar los deja como estaban.
  final List<String>? contactIds;
  final MissionType type;
  final MissionImportance importance;
  final MissionPriority priority;
  final MissionDifficulty? difficulty;
  final bool isRequired;
  final DateTime? scheduledAtUtc;
  final DateTime? availableFromUtc;
  final DateTime? expiresAtUtc;
  final int? estimatedMinutes;
  final int? budgetMinor;
  final int xpPlanned;
  final List<MissionObjectiveDraft> objectives;
}

final class MissionApplicationService {
  const MissionApplicationService({
    required MissionRepository repository,
    required MissionClock clock,
    required MissionIdGenerator idGenerator,
  }) : _repository = repository,
       _clock = clock,
       _idGenerator = idGenerator;

  final MissionRepository _repository;
  final MissionClock _clock;
  final MissionIdGenerator _idGenerator;

  Future<Result<Mission>> save(SaveMissionRequest request) {
    final DateTime nowUtc = _clock.nowUtc();
    final Mission? existing = request.existing;
    final String missionId = existing?.id ?? _idGenerator.nextId();
    final List<MissionObjective> objectives = <MissionObjective>[
      for (var index = 0; index < request.objectives.length; index++)
        MissionObjective(
          id: request.objectives[index].id ?? _idGenerator.nextId(),
          description: request.objectives[index].description,
          position: index,
          createdAtUtc: request.objectives[index].createdAtUtc ?? nowUtc,
          completedAtUtc: request.objectives[index].completedAtUtc,
        ),
    ];

    final MissionStatus plannedStatus = _statusForSchedule(
      existing: existing,
      scheduledAtUtc: request.scheduledAtUtc,
      nowUtc: nowUtc,
    );
    final Mission mission = existing == null
        ? Mission(
            id: missionId,
            areaId: request.areaId,
            title: request.title,
            description: request.description,
            location: request.location,
            type: request.type,
            importance: request.importance,
            priority: request.priority,
            difficulty: request.difficulty,
            isRequired: request.isRequired,
            status: plannedStatus,
            scheduledAtUtc: request.scheduledAtUtc,
            availableFromUtc: request.availableFromUtc,
            expiresAtUtc: request.expiresAtUtc,
            estimatedMinutes: request.estimatedMinutes,
            budgetMinor: request.budgetMinor,
            xpPlanned: request.xpPlanned,
            rowVersion: 1,
            objectives: objectives,
          )
        : Mission(
            id: existing.id,
            templateId: existing.templateId,
            areaId: request.areaId,
            title: request.title,
            description: request.description,
            location: request.location,
            type: request.type,
            importance: request.importance,
            priority: request.priority,
            difficulty: request.difficulty,
            isRequired: request.isRequired,
            status: plannedStatus,
            scheduledAtUtc: request.scheduledAtUtc,
            availableFromUtc: request.availableFromUtc,
            expiresAtUtc: request.expiresAtUtc,
            estimatedMinutes: request.estimatedMinutes,
            budgetMinor: request.budgetMinor,
            xpPlanned: request.xpPlanned,
            actualResult: existing.actualResult,
            convenienceRating: existing.convenienceRating,
            completedAtUtc: existing.completedAtUtc,
            archivedAtUtc: existing.archivedAtUtc,
            rowVersion: existing.rowVersion,
            objectives: objectives,
            timeEntries: existing.timeEntries,
          );

    final String eventId = _idGenerator.nextId();
    final String notificationId = _idGenerator.nextId();
    final String expiryNotificationId = _idGenerator.nextId();
    return existing == null
        ? _repository.create(
            mission,
            eventId: eventId,
            notificationId: notificationId,
            expiryNotificationId: expiryNotificationId,
            occurredAtUtc: nowUtc,
            contactIds: request.contactIds ?? const <String>[],
          )
        : _repository.update(
            mission,
            eventId: eventId,
            notificationId: notificationId,
            expiryNotificationId: expiryNotificationId,
            occurredAtUtc: nowUtc,
            contactIds: request.contactIds,
          );
  }

  MissionStatus _statusForSchedule({
    required Mission? existing,
    required DateTime? scheduledAtUtc,
    required DateTime nowUtc,
  }) {
    if (existing != null &&
        !const <MissionStatus>{
          MissionStatus.draft,
          MissionStatus.scheduled,
          MissionStatus.available,
          MissionStatus.rescheduled,
        }.contains(existing.status)) {
      return existing.status;
    }
    return scheduledAtUtc?.isAfter(nowUtc) == true
        ? MissionStatus.scheduled
        : MissionStatus.available;
  }

  Future<Result<Mission>> startTimer(Mission mission) {
    if (!const <MissionStatus>{
      MissionStatus.scheduled,
      MissionStatus.available,
      MissionStatus.rescheduled,
      MissionStatus.paused,
    }.contains(mission.status)) {
      return Future<Result<Mission>>.value(
        const Failure<Mission>(
          ValidationFailure('El estado actual no permite iniciar el tiempo.'),
        ),
      );
    }
    final DateTime nowUtc = _clock.nowUtc();
    return _repository.startTimer(
      missionId: mission.id,
      expectedRowVersion: mission.rowVersion,
      expectedStatus: mission.status,
      timeEntryId: _idGenerator.nextId(),
      eventId: _idGenerator.nextId(),
      occurredAtUtc: nowUtc,
    );
  }

  Future<Result<Mission>> pauseTimer(Mission mission) {
    if (mission.status != MissionStatus.active ||
        mission.openWorkTimer == null) {
      return Future<Result<Mission>>.value(
        const Failure<Mission>(
          ValidationFailure('La misión no tiene un cronómetro activo.'),
        ),
      );
    }
    final DateTime nowUtc = _clock.nowUtc();
    return _repository.pauseTimer(
      missionId: mission.id,
      expectedRowVersion: mission.rowVersion,
      eventId: _idGenerator.nextId(),
      occurredAtUtc: nowUtc,
    );
  }

  Future<Result<Mission>> switchTimer({
    required Mission activeMission,
    required Mission targetMission,
  }) {
    if (activeMission.id == targetMission.id ||
        activeMission.status != MissionStatus.active ||
        activeMission.openWorkTimer == null ||
        !const <MissionStatus>{
          MissionStatus.scheduled,
          MissionStatus.available,
          MissionStatus.rescheduled,
          MissionStatus.paused,
        }.contains(targetMission.status)) {
      return Future<Result<Mission>>.value(
        const Failure<Mission>(
          ValidationFailure('No se puede cambiar a esta misión.'),
        ),
      );
    }
    return _repository.switchTimer(
      activeMission: activeMission,
      targetMission: targetMission,
      pauseEventId: _idGenerator.nextId(),
      timeEntryId: _idGenerator.nextId(),
      startEventId: _idGenerator.nextId(),
      occurredAtUtc: _clock.nowUtc(),
    );
  }

  Future<Result<Mission>> archiveMission(Mission mission) {
    if (mission.archivedAtUtc != null ||
        mission.status == MissionStatus.active ||
        mission.openWorkTimer != null) {
      return Future<Result<Mission>>.value(
        const Failure<Mission>(
          ValidationFailure(
            'Pausa el cronómetro antes de archivar esta misión.',
          ),
        ),
      );
    }
    return _repository.archive(
      mission: mission,
      eventId: _idGenerator.nextId(),
      occurredAtUtc: _clock.nowUtc(),
    );
  }
}
