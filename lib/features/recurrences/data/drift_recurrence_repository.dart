import 'package:drift/drift.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../infrastructure/database/app_database.dart' as drift;
import '../../../infrastructure/database/daos/dao_support.dart';
import '../../../infrastructure/database/daos/recurrence_dao.dart';
import '../domain/models/recurrence_template.dart';
import '../domain/repositories/recurrence_repository.dart';
import 'recurrence_mapper.dart';

final class DriftRecurrenceRepository implements RecurrenceRepository {
  const DriftRecurrenceRepository(this._dao);

  final RecurrenceDao _dao;

  @override
  Stream<Result<List<RecurrenceTemplate>>> watchActiveTemplates() =>
      _watchTemplates(activeOnly: true);

  @override
  Stream<Result<List<RecurrenceTemplate>>> watchAllTemplates() =>
      _watchTemplates(activeOnly: false);

  Stream<Result<List<RecurrenceTemplate>>> _watchTemplates({
    required bool activeOnly,
  }) {
    final stream = activeOnly
        ? _dao.watchActiveTemplates()
        : _dao.watchAllTemplates();
    return stream.asyncMap((templates) async {
      try {
        final List<RecurrenceTemplate> result = <RecurrenceTemplate>[];
        for (final t in templates) {
          final bundle = await _dao.findTemplateBundle(t.id);
          if (bundle != null) {
            result.add(RecurrenceMapper.fromBundle(bundle));
          }
        }
        return Success<List<RecurrenceTemplate>>(result);
      } on Object catch (error) {
        return Failure<List<RecurrenceTemplate>>(
          StorageFailure('No se pudieron cargar las plantillas.', cause: error),
        );
      }
    });
  }

  @override
  Future<Result<RecurrenceTemplate?>> findById(String templateId) async {
    if (templateId.trim().isEmpty) {
      return const Failure<RecurrenceTemplate?>(
        ValidationFailure('El identificador de plantilla es obligatorio.'),
      );
    }
    try {
      final bundle = await _dao.findTemplateBundle(templateId);
      return Success<RecurrenceTemplate?>(
        bundle == null ? null : RecurrenceMapper.fromBundle(bundle),
      );
    } on Object catch (error) {
      return Failure<RecurrenceTemplate?>(
        StorageFailure('No se pudo leer la plantilla.', cause: error),
      );
    }
  }

  @override
  Future<Result<RecurrenceTemplate>> create(
    RecurrenceTemplate template, {
    required String ruleId,
  }) async {
    if (template.rule == null) {
      return const Failure<RecurrenceTemplate>(
        ValidationFailure(
          'Una plantilla nueva requiere una regla de recurrencia.',
        ),
      );
    }
    final rule = template.rule!;
    try {
      final bundle = await _dao.insertTemplateAggregate(
        template: _templateCompanion(template),
        objectives: template.objectives.map(
          (o) => _objectiveCompanion(o, template.id),
        ),
        rule: _ruleCompanion(ruleId, template.id, rule),
      );
      return Success<RecurrenceTemplate>(RecurrenceMapper.fromBundle(bundle));
    } on Object catch (error) {
      return Failure<RecurrenceTemplate>(
        StorageFailure('No se pudo crear la plantilla.', cause: error),
      );
    }
  }

  @override
  Future<Result<RecurrenceTemplate>> update(RecurrenceTemplate template) async {
    if (template.rule == null) {
      return const Failure<RecurrenceTemplate>(
        ValidationFailure(
          'La actualización requiere una regla de recurrencia.',
        ),
      );
    }
    final rule = template.rule!;
    try {
      final bundle = await _dao.updateTemplateAggregate(
        template: _templateCompanion(template),
        objectives: template.objectives.map(
          (o) => _objectiveCompanion(o, template.id),
        ),
        rule: _ruleCompanion(rule.id, template.id, rule),
      );
      return Success<RecurrenceTemplate>(RecurrenceMapper.fromBundle(bundle));
    } on RecordNotFoundException {
      return const Failure<RecurrenceTemplate>(
        StorageFailure('La plantilla que intentas editar ya no existe.'),
      );
    } on Object catch (error) {
      return Failure<RecurrenceTemplate>(
        StorageFailure('No se pudo actualizar la plantilla.', cause: error),
      );
    }
  }

  @override
  Future<Result<RecurrenceTemplate>> pause(String templateId) =>
      _setActive(templateId, isActive: false);

  @override
  Future<Result<RecurrenceTemplate>> resume(String templateId) =>
      _setActive(templateId, isActive: true);

  Future<Result<RecurrenceTemplate>> _setActive(
    String templateId, {
    required bool isActive,
  }) async {
    try {
      await _dao.setTemplateActive(templateId, isActive: isActive);
      final bundle = await _dao.findTemplateBundle(templateId);
      if (bundle == null) {
        throw RecordNotFoundException(
          table: 'mission_templates',
          key: templateId,
        );
      }
      return Success<RecurrenceTemplate>(RecurrenceMapper.fromBundle(bundle));
    } on RecordNotFoundException {
      return const Failure<RecurrenceTemplate>(
        StorageFailure('La plantilla que intentas modificar ya no existe.'),
      );
    } on Object catch (error) {
      return Failure<RecurrenceTemplate>(
        StorageFailure(
          'No se pudo cambiar el estado de la plantilla.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> deleteIfUnused(String templateId) async {
    try {
      await _dao.deleteUnusedTemplate(templateId);
      return const Success<void>(null);
    } on DatabaseInvariantException catch (error) {
      return Failure<void>(
        ConflictFailure(
          'La plantilla no puede borrarse porque tiene misiones generadas: '
          '${error.message}',
        ),
      );
    } on RecordNotFoundException {
      return const Success<void>(null); // idempotente
    } on Object catch (error) {
      return Failure<void>(
        StorageFailure('No se pudo eliminar la plantilla.', cause: error),
      );
    }
  }

  // ── helpers dominio → Drift ─────────────────────────────────────────────

  drift.MissionTemplatesCompanion _templateCompanion(
    RecurrenceTemplate t,
  ) => drift.MissionTemplatesCompanion(
    id: Value<String>(t.id),
    areaId: Value<String>(t.areaId),
    title: Value<String>(t.title),
    description: Value<String?>(t.description),
    missionType: Value<String>(RecurrenceMapper.missionTypeToDb(t.missionType)),
    importance: Value<String>(RecurrenceMapper.importanceToDb(t.importance)),
    priority: Value<String>(RecurrenceMapper.priorityToDb(t.priority)),
    difficulty: Value<String?>(RecurrenceMapper.difficultyToDb(t.difficulty)),
    isRequired: Value<int>(t.isRequired ? 1 : 0),
    xpReward: Value<int>(t.xpReward),
    estimatedMinutes: Value<int?>(t.estimatedMinutes),
    budgetMinor: Value<int?>(t.budgetMinor),
    location: Value<String?>(t.location),
    availabilityMode: Value<String>(
      RecurrenceMapper.availabilityModeToDb(t.availabilityMode),
    ),
    isActive: Value<int>(t.isActive ? 1 : 0),
  );

  drift.MissionTemplateObjectivesCompanion _objectiveCompanion(
    RecurrenceObjective o,
    String templateId,
  ) {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    return drift.MissionTemplateObjectivesCompanion(
      id: Value<String>(o.id),
      templateId: Value<String>(templateId),
      description: Value<String>(o.description),
      position: Value<int>(o.position),
      createdAt: Value<int>(nowMs),
      updatedAt: Value<int>(nowMs),
    );
  }

  drift.RecurrenceRulesCompanion _ruleCompanion(
    String ruleId,
    String templateId,
    RecurrenceRule r,
  ) => drift.RecurrenceRulesCompanion(
    id: Value<String>(ruleId),
    templateId: Value<String>(templateId),
    frequency: Value<String>(RecurrenceMapper.frequencyToDb(r.frequency)),
    intervalValue: Value<int>(r.intervalValue),
    weekdaysMask: Value<int?>(r.weekdaysMask),
    localTimeMinutes: Value<int?>(r.localTimeMinutes),
    startDate: Value<String>(r.startDate),
    endDate: Value<String?>(r.endDate),
    timezoneId: Value<String>(r.timezoneId),
    lastGeneratedOn: Value<String?>(r.lastGeneratedOn),
  );
}
