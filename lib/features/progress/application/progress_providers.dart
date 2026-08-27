import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/persistence_providers.dart';
import '../domain/models/progress_models.dart';
import 'progress_application_service.dart';

final Provider<ProgressClock> progressClockProvider = Provider<ProgressClock>(
  (Ref ref) => const SystemProgressClock(),
);

final Provider<ProgressApplicationService> progressApplicationServiceProvider =
    Provider<ProgressApplicationService>(
      (Ref ref) => ProgressApplicationService(
        progressRepository: ref.watch(progressRepositoryProvider),
        dailyCloseRepository: ref.watch(dailyCloseRepositoryProvider),
        missionRepository: ref.watch(missionRepositoryProvider),
        clock: ref.watch(progressClockProvider),
      ),
    );

final dailyDashboardProvider = FutureProvider.autoDispose
    .family<DailyDashboardViewData, DateTime>((
      Ref ref,
      DateTime localDay,
    ) async {
      final result = await ref
          .watch(progressApplicationServiceProvider)
          .loadDailyDashboard(localDay);
      return result.fold(
        onSuccess: (value) => value,
        onFailure: (failure) => throw failure,
      );
    });

final weeklyDashboardProvider = FutureProvider.autoDispose
    .family<WeeklyDashboardViewData, DateTime>((
      Ref ref,
      DateTime localDay,
    ) async {
      final result = await ref
          .watch(progressApplicationServiceProvider)
          .loadWeeklyDashboard(localDay);
      return result.fold(
        onSuccess: (value) => value,
        onFailure: (failure) => throw failure,
      );
    });

final overallProgressProvider =
    FutureProvider.autoDispose<OverallProgressViewData>((Ref ref) async {
      final result = await ref
          .watch(progressApplicationServiceProvider)
          .loadOverallProgress();
      return result.fold(
        onSuccess: (value) => value,
        onFailure: (failure) => throw failure,
      );
    });
