import '../../../../core/result/result.dart';
import '../models/mission.dart';

abstract interface class MissionRepository {
  Future<Result<Mission?>> findById(String id);

  Future<Result<Mission?>> findActiveTimer();

  Future<Result<List<MissionArea>>> findVisibleAreas();

  Future<Result<List<Mission>>> findScheduledBetween({
    required DateTime startUtc,
    required DateTime endUtc,
  });

  Stream<Result<List<Mission>>> watchScheduledBetween({
    required DateTime startUtc,
    required DateTime endUtc,
  });

  Stream<Result<List<Mission>>> watchUpcoming({required DateTime startUtc});

  Stream<Result<List<Mission>>> watchAll();

  Future<Result<Mission>> create(
    Mission mission, {
    required String eventId,
    required DateTime occurredAtUtc,
  });

  Future<Result<Mission>> update(
    Mission mission, {
    required String eventId,
    required DateTime occurredAtUtc,
  });

  Future<Result<Mission>> startTimer({
    required String missionId,
    required int expectedRowVersion,
    required MissionStatus expectedStatus,
    required String timeEntryId,
    required String eventId,
    required DateTime occurredAtUtc,
  });

  Future<Result<Mission>> pauseTimer({
    required String missionId,
    required int expectedRowVersion,
    required String eventId,
    required DateTime occurredAtUtc,
  });

  Future<Result<Mission>> switchTimer({
    required Mission activeMission,
    required Mission targetMission,
    required String pauseEventId,
    required String timeEntryId,
    required String startEventId,
    required DateTime occurredAtUtc,
  });
}
