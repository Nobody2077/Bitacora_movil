import 'dart:math';

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
    required this.scheduledAtUtc,
    required this.xpPlanned,
    required this.objectives,
    this.existing,
    this.description,
    this.difficulty,
    this.estimatedMinutes,
    this.budgetMinor,
  });

  final Mission? existing;
  final String areaId;
  final String title;
  final String? description;
  final MissionType type;
  final MissionImportance importance;
  final MissionPriority priority;
  final MissionDifficulty? difficulty;
  final bool isRequired;
  final DateTime scheduledAtUtc;
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

    final Mission mission = existing == null
        ? Mission(
            id: missionId,
            areaId: request.areaId,
            title: request.title,
            description: request.description,
            type: request.type,
            importance: request.importance,
            priority: request.priority,
            difficulty: request.difficulty,
            isRequired: request.isRequired,
            status: request.scheduledAtUtc.isAfter(nowUtc)
                ? MissionStatus.scheduled
                : MissionStatus.available,
            scheduledAtUtc: request.scheduledAtUtc,
            estimatedMinutes: request.estimatedMinutes,
            budgetMinor: request.budgetMinor,
            xpPlanned: request.xpPlanned,
            rowVersion: 1,
            objectives: objectives,
          )
        : existing.copyWith(
            areaId: request.areaId,
            title: request.title,
            description: request.description,
            type: request.type,
            importance: request.importance,
            priority: request.priority,
            difficulty: request.difficulty,
            isRequired: request.isRequired,
            scheduledAtUtc: request.scheduledAtUtc,
            estimatedMinutes: request.estimatedMinutes,
            budgetMinor: request.budgetMinor,
            xpPlanned: request.xpPlanned,
            objectives: objectives,
          );

    final String eventId = _idGenerator.nextId();
    return existing == null
        ? _repository.create(mission, eventId: eventId, occurredAtUtc: nowUtc)
        : _repository.update(mission, eventId: eventId, occurredAtUtc: nowUtc);
  }
}
