import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/persistence_providers.dart';
import '../../../core/result/result.dart';
import '../../../features/missions/application/mission_providers.dart';
import '../data/method_channel_recurrence_civil_time.dart';
import '../domain/models/recurrence_template.dart';
import 'recurrence_application_service.dart';
import 'recurrence_civil_time.dart';

final Provider<RecurrenceCivilTime> recurrenceCivilTimeProvider =
    Provider<RecurrenceCivilTime>(
      (Ref ref) => const MethodChannelRecurrenceCivilTime(),
    );

final Provider<RecurrenceApplicationService>
recurrenceApplicationServiceProvider = Provider<RecurrenceApplicationService>(
  (Ref ref) => RecurrenceApplicationService(
    repository: ref.watch(recurrenceRepositoryProvider),
    dao: ref.watch(recurrenceDaoProvider),
    clock: ref.watch(missionClockProvider),
    idGenerator: ref.watch(missionIdGeneratorProvider),
    civilTime: ref.watch(recurrenceCivilTimeProvider),
  ),
);

/// Todas las plantillas (activas y pausadas) en tiempo real.
final StreamProvider<List<RecurrenceTemplate>> allTemplatesProvider =
    StreamProvider<List<RecurrenceTemplate>>((Ref ref) {
      return ref
          .watch(recurrenceRepositoryProvider)
          .watchAllTemplates()
          .map(
            (result) =>
                result.fold(onSuccess: (t) => t, onFailure: (f) => throw f),
          );
    });

/// Solo plantillas activas en tiempo real.
final StreamProvider<List<RecurrenceTemplate>> activeTemplatesProvider =
    StreamProvider<List<RecurrenceTemplate>>((Ref ref) {
      return ref
          .watch(recurrenceRepositoryProvider)
          .watchActiveTemplates()
          .map(
            (result) =>
                result.fold(onSuccess: (t) => t, onFailure: (f) => throw f),
          );
    });

/// Detalle de una plantilla por id.
FutureProvider<RecurrenceTemplate?> templateDetailProvider(String templateId) =>
    FutureProvider<RecurrenceTemplate?>((Ref ref) async {
      final Result<RecurrenceTemplate?> result = await ref
          .watch(recurrenceRepositoryProvider)
          .findById(templateId);
      return result.fold(onSuccess: (t) => t, onFailure: (f) => throw f);
    });
