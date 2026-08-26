import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../features/missions/domain/models/mission.dart';

enum MissionCompletionOutcome { completed, partial }

enum CompletionPaymentMethod { cash, bank, wallet }

enum CompletionMovementType { expense, income }

final class CompleteMissionRequest {
  const CompleteMissionRequest({
    required this.mission,
    required this.outcome,
    required this.actualResult,
    required this.completedObjectiveIds,
    this.convenienceRating,
    this.journalNote,
    this.movementMinor,
    this.movementCategory,
    this.movementType = CompletionMovementType.expense,
    this.paymentMethod,
  });

  final Mission mission;
  final MissionCompletionOutcome outcome;
  final String actualResult;
  final ConvenienceRating? convenienceRating;
  final Set<String> completedObjectiveIds;
  final String? journalNote;
  final int? movementMinor;
  final String? movementCategory;
  final CompletionMovementType movementType;
  final CompletionPaymentMethod? paymentMethod;
}

final class CompleteMissionOperation {
  const CompleteMissionOperation({
    required this.request,
    required this.occurredAtUtc,
    required this.eventId,
    required this.journalEntryId,
    required this.xpTransactionId,
    required this.movementTransactionId,
    required this.movementOperationId,
  });

  final CompleteMissionRequest request;
  final DateTime occurredAtUtc;
  final String eventId;
  final String journalEntryId;
  final String xpTransactionId;
  final String movementTransactionId;
  final String movementOperationId;
}

final class MissionCompletionReceipt {
  const MissionCompletionReceipt({
    required this.mission,
    required this.xpAwarded,
    required this.totalWorkSeconds,
    this.journalEntryId,
    this.movementMinor,
    this.movementType,
  });

  final Mission mission;
  final int xpAwarded;
  final int totalWorkSeconds;
  final String? journalEntryId;
  final int? movementMinor;
  final CompletionMovementType? movementType;
}

abstract interface class CompleteMissionUnitOfWork {
  Future<Result<MissionCompletionReceipt>> complete(
    CompleteMissionOperation operation,
  );

  Future<Result<MissionCompletionReceipt?>> findReceipt(String missionId);
}

typedef CompleteMissionClock = DateTime Function();
typedef CompleteMissionIdFactory = String Function();

final class CompleteMissionCommand {
  const CompleteMissionCommand({
    required CompleteMissionUnitOfWork unitOfWork,
    required CompleteMissionClock nowUtc,
    required CompleteMissionIdFactory nextId,
  }) : _unitOfWork = unitOfWork,
       _nowUtc = nowUtc,
       _nextId = nextId;

  final CompleteMissionUnitOfWork _unitOfWork;
  final CompleteMissionClock _nowUtc;
  final CompleteMissionIdFactory _nextId;

  Future<Result<MissionCompletionReceipt>> call(
    CompleteMissionRequest request,
  ) {
    final ValidationFailure? invalid = _validate(request);
    if (invalid != null) {
      return Future<Result<MissionCompletionReceipt>>.value(
        Failure<MissionCompletionReceipt>(invalid),
      );
    }
    return _unitOfWork.complete(
      CompleteMissionOperation(
        request: request,
        occurredAtUtc: _nowUtc(),
        eventId: _nextId(),
        journalEntryId: _nextId(),
        xpTransactionId: _nextId(),
        movementTransactionId: _nextId(),
        movementOperationId: _nextId(),
      ),
    );
  }

  ValidationFailure? _validate(CompleteMissionRequest request) {
    final Mission mission = request.mission;
    if (!const <MissionStatus>{
      MissionStatus.scheduled,
      MissionStatus.available,
      MissionStatus.active,
      MissionStatus.paused,
      MissionStatus.rescheduled,
    }.contains(mission.status)) {
      return const ValidationFailure(
        'El estado actual de la misión no permite completarla.',
      );
    }
    final String actualResult = request.actualResult.trim();
    if (actualResult.isEmpty || actualResult.length > 2000) {
      return const ValidationFailure(
        'Describe el resultado real en un máximo de 2000 caracteres.',
      );
    }
    final Set<String> knownObjectives = mission.objectives
        .map((objective) => objective.id)
        .toSet();
    if (!knownObjectives.containsAll(request.completedObjectiveIds)) {
      return const ValidationFailure(
        'La selección contiene objetivos que no pertenecen a la misión.',
      );
    }
    if (request.outcome == MissionCompletionOutcome.completed &&
        request.completedObjectiveIds.length != knownObjectives.length) {
      return const ValidationFailure(
        'Marca todos los objetivos para completar totalmente la misión.',
      );
    }
    if (request.movementMinor != null && request.movementMinor! <= 0) {
      return const ValidationFailure(
        'El movimiento real debe ser mayor que cero.',
      );
    }
    if (request.movementMinor != null && request.paymentMethod == null) {
      return const ValidationFailure(
        'Selecciona el medio de pago del gasto real.',
      );
    }
    if ((request.journalNote?.trim().length ?? 0) > 4000 ||
        (request.movementCategory?.trim().length ?? 0) > 120) {
      return const ValidationFailure(
        'La nota o la categoría superan el tamaño permitido.',
      );
    }
    return null;
  }
}
