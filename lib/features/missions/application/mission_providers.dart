import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/persistence_providers.dart';
import '../../../core/result/result.dart';
import '../domain/models/mission.dart';
import '../domain/repositories/mission_repository.dart';
import 'mission_application_service.dart';

final Provider<MissionClock> missionClockProvider = Provider<MissionClock>(
  (Ref ref) => const SystemMissionClock(),
);

final Provider<MissionIdGenerator> missionIdGeneratorProvider =
    Provider<MissionIdGenerator>((Ref ref) => SecureMissionIdGenerator());

final Provider<MissionApplicationService> missionApplicationServiceProvider =
    Provider<MissionApplicationService>(
      (Ref ref) => MissionApplicationService(
        repository: ref.watch(missionRepositoryProvider),
        clock: ref.watch(missionClockProvider),
        idGenerator: ref.watch(missionIdGeneratorProvider),
      ),
    );

final FutureProvider<List<MissionArea>> missionAreasProvider =
    FutureProvider<List<MissionArea>>((Ref ref) async {
      final Result<List<MissionArea>> result = await ref
          .watch(missionRepositoryProvider)
          .findVisibleAreas();
      return result.fold(
        onSuccess: (areas) => areas,
        onFailure: (failure) => throw failure,
      );
    });

final StreamProvider<List<Mission>> todayMissionsProvider =
    StreamProvider<List<Mission>>((Ref ref) {
      final DateTime localNow = DateTime.now();
      final DateTime startUtc = DateTime(
        localNow.year,
        localNow.month,
        localNow.day,
      ).toUtc();
      final DateTime endUtc = DateTime(
        localNow.year,
        localNow.month,
        localNow.day + 1,
      ).toUtc();
      final MissionRepository repository = ref.watch(missionRepositoryProvider);
      return repository
          .watchScheduledBetween(startUtc: startUtc, endUtc: endUtc)
          .map(
            (result) => result.fold(
              onSuccess: (missions) => missions,
              onFailure: (failure) => throw failure,
            ),
          );
    });

final missionDetailProvider = FutureProvider.family<Mission?, String>((
  Ref ref,
  String missionId,
) async {
  final Result<Mission?> result = await ref
      .watch(missionRepositoryProvider)
      .findById(missionId);
  return result.fold(
    onSuccess: (mission) => mission,
    onFailure: (failure) => throw failure,
  );
});
