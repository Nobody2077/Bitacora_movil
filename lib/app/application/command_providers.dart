import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../features/missions/application/mission_providers.dart';
import '../providers/persistence_providers.dart';
import 'commands/complete_mission.dart';

final Provider<CompleteMissionCommand> completeMissionCommandProvider =
    Provider<CompleteMissionCommand>(
      (Ref ref) => CompleteMissionCommand(
        unitOfWork: ref.watch(completeMissionUnitOfWorkProvider),
        nowUtc: ref.watch(missionClockProvider).nowUtc,
        nextId: ref.watch(missionIdGeneratorProvider).nextId,
      ),
    );

final missionCompletionReceiptProvider =
    FutureProvider.family<MissionCompletionReceipt?, String>((
      Ref ref,
      String missionId,
    ) async {
      final result = await ref
          .watch(completeMissionUnitOfWorkProvider)
          .findReceipt(missionId);
      return result.fold(
        onSuccess: (receipt) => receipt,
        onFailure: (AppFailure failure) => throw failure,
      );
    });
