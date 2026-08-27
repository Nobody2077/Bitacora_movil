import '../../../../core/result/result.dart';
import '../models/recurrence_template.dart';

abstract interface class RecurrenceRepository {
  /// Stream de todas las plantillas activas en tiempo real.
  Stream<Result<List<RecurrenceTemplate>>> watchActiveTemplates();

  /// Todas las plantillas (activas y pausadas) en tiempo real.
  Stream<Result<List<RecurrenceTemplate>>> watchAllTemplates();

  /// Lee el agregado completo de una plantilla por su id.
  Future<Result<RecurrenceTemplate?>> findById(String templateId);

  /// Crea un nuevo agregado de plantilla + regla en una sola transacción.
  Future<Result<RecurrenceTemplate>> create(
    RecurrenceTemplate template, {
    required String ruleId,
  });

  /// Reemplaza los campos de una plantilla existente y actualiza su regla.
  Future<Result<RecurrenceTemplate>> update(RecurrenceTemplate template);

  /// Pausa una plantilla activa. Las ocurrencias ya generadas no se borran.
  Future<Result<RecurrenceTemplate>> pause(String templateId);

  /// Reactiva una plantilla pausada.
  Future<Result<RecurrenceTemplate>> resume(String templateId);

  /// Borra una plantilla sólo si no tiene misiones generadas.
  Future<Result<void>> deleteIfUnused(String templateId);
}
