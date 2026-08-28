import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../infrastructure/database/daos/progress_dao.dart';
import '../../../infrastructure/database/default_seed_v1.dart';
import '../domain/models/progress_models.dart';
import '../domain/models/progress_snapshot.dart';
import '../domain/repositories/progress_repository.dart';

final class DriftProgressRepository implements ProgressRepository {
  const DriftProgressRepository(this._dao);

  final ProgressDao _dao;

  @override
  Future<Result<ProgressSnapshot>> loadSnapshot({
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    required DateTime weekStartUtc,
  }) async {
    if (!dayStartUtc.isUtc ||
        !dayEndUtc.isUtc ||
        !weekStartUtc.isUtc ||
        !dayEndUtc.isAfter(dayStartUtc) ||
        weekStartUtc.isAfter(dayStartUtc)) {
      return const Failure<ProgressSnapshot>(
        ValidationFailure(
          'Los períodos de progreso deben usar límites UTC válidos.',
        ),
      );
    }

    try {
      final todayFuture = _dao
          .watchTotals(
            periodStartUtcMs: dayStartUtc.millisecondsSinceEpoch,
            periodEndUtcMs: dayEndUtc.millisecondsSinceEpoch,
          )
          .first;
      final weekFuture = _dao
          .watchTotals(
            periodStartUtcMs: weekStartUtc.millisecondsSinceEpoch,
            periodEndUtcMs: dayEndUtc.millisecondsSinceEpoch,
          )
          .first;
      final areasFuture = _dao.watchAreaTotals().first;

      final today = await todayFuture;
      final week = await weekFuture;
      final areas = await areasFuture;
      return Success<ProgressSnapshot>(
        ProgressSnapshot(
          totalXp: today.effectiveTotal,
          todayXp: today.effectivePeriodTotal,
          weekXp: week.effectivePeriodTotal,
          byArea: areas
              .map(
                (area) =>
                    AreaXp(areaId: area.areaId, amount: area.effectiveTotal),
              )
              .toList(growable: false),
        ),
      );
    } on Object catch (error) {
      return Failure<ProgressSnapshot>(
        StorageFailure('No se pudo leer el progreso.', cause: error),
      );
    }
  }

  @override
  Future<Result<ProgressTitleRuleFacts>> loadTitleRuleFacts() async {
    try {
      final facts = await _dao.loadTitleRuleFacts(
        homeAreaId: DefaultSeedV1.homeAreaId,
      );
      return Success<ProgressTitleRuleFacts>(
        ProgressTitleRuleFacts(
          definitions: facts.definitions
              .map(
                (definition) => ProgressTitleDefinition(
                  id: definition.id,
                  name: definition.name,
                  description: definition.description,
                  kind: ProgressTitleKind.fromStorage(definition.titleKind),
                  ruleKey: definition.ruleKey,
                  threshold: definition.threshold ?? 0,
                ),
              )
              .toList(growable: false),
          completedHomeMissions: facts.completedHomeMissions,
          completionInstantsUtc: facts.completionInstantsUtcMs
              .map(
                (value) =>
                    DateTime.fromMillisecondsSinceEpoch(value, isUtc: true),
              )
              .toList(growable: false),
        ),
      );
    } on Object catch (error) {
      return Failure<ProgressTitleRuleFacts>(
        StorageFailure(
          'No se pudieron calcular las reglas de títulos.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<List<TitleProgressItem>>> synchronizeTitles({
    required List<ProgressTitleDecision> decisions,
    required DateTime evaluatedAtUtc,
  }) async {
    if (!evaluatedAtUtc.isUtc ||
        decisions.any(
          (decision) =>
              decision.titleId.trim().isEmpty || decision.bestStreak < 0,
        )) {
      return const Failure<List<TitleProgressItem>>(
        ValidationFailure('La evaluación de títulos no es válida.'),
      );
    }
    try {
      final titles = await _dao.synchronizeTitleStates(
        decisions: decisions
            .map(
              (decision) => TitleStateDecisionInput(
                titleId: decision.titleId,
                achieved: decision.achieved,
                bestStreak: decision.bestStreak,
              ),
            )
            .toList(growable: false),
        evaluatedAtUtcMs: evaluatedAtUtc.millisecondsSinceEpoch,
      );
      return Success<List<TitleProgressItem>>(
        titles
            .map(
              (title) => TitleProgressItem(
                id: title.definition.id,
                name: title.definition.name,
                description: title.definition.description,
                kind: ProgressTitleKind.fromStorage(title.definition.titleKind),
                status: ProgressTitleStatus.fromStorage(title.history.status),
                activatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
                  title.history.activatedAt,
                  isUtc: true,
                ),
                bestStreak: title.history.bestStreak,
                recoveryCount: title.history.recoveryCount,
              ),
            )
            .toList(growable: false),
      );
    } on Object catch (error) {
      return Failure<List<TitleProgressItem>>(
        StorageFailure(
          'No se pudo actualizar el historial de títulos.',
          cause: error,
        ),
      );
    }
  }

  @override
  Stream<void> watchChanges() => _dao.watchChanges();
}
