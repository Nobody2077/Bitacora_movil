import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../economy/application/economy_application_service.dart'
    show EconomyClock, EconomyIdGenerator;
import '../../economy/domain/models/economy_models.dart';
import '../domain/models/wish.dart';
import '../domain/repositories/wish_repository.dart';

final class SaveWishRequest {
  const SaveWishRequest({
    required this.name,
    required this.kind,
    this.existing,
    this.description,
    this.areaId,
    this.priority = WishPriority.medium,
    this.priceMinor,
  });

  final Wish? existing;
  final String name;
  final String? description;
  final String? areaId;
  final WishKind kind;
  final WishPriority priority;
  final int? priceMinor;
}

final class PurchaseWishRequest {
  const PurchaseWishRequest({
    required this.wish,
    required this.amountMinor,
    required this.paymentMethod,
  });

  final Wish wish;

  /// Precio real pagado; la pantalla propone el orientativo.
  final int amountMinor;
  final EconomyPaymentMethod paymentMethod;
}

/// La Tienda (ADR-006 D17): lista de deseos y su compra con dinero real.
/// Usa el reloj y los ids de Economía porque cada compra es un gasto.
final class ShopApplicationService {
  const ShopApplicationService({
    required WishRepository repository,
    required EconomyClock clock,
    required EconomyIdGenerator idGenerator,
  }) : _repository = repository,
       _clock = clock,
       _idGenerator = idGenerator;

  /// Categoría de Economía de todas las compras de la Tienda.
  static const String purchaseCategory = 'Tienda';

  final WishRepository _repository;
  final EconomyClock _clock;
  final EconomyIdGenerator _idGenerator;

  Future<Result<Wish>> save(SaveWishRequest request) async {
    final String name = request.name.trim();
    final String? description = _blankToNull(request.description);
    final String? areaId = _blankToNull(request.areaId);
    if (name.isEmpty) {
      return const Failure<Wish>(
        ValidationFailure('El deseo necesita un nombre.'),
      );
    }
    if (name.length > Wish.maxNameLength) {
      return const Failure<Wish>(
        ValidationFailure(
          'El nombre admite hasta ${Wish.maxNameLength} caracteres.',
        ),
      );
    }
    if ((description?.length ?? 0) > Wish.maxDescriptionLength) {
      return const Failure<Wish>(
        ValidationFailure(
          'La información admite hasta ${Wish.maxDescriptionLength} '
          'caracteres.',
        ),
      );
    }
    if (request.priceMinor != null && request.priceMinor! <= 0) {
      return const Failure<Wish>(
        ValidationFailure('El precio debe ser mayor que cero.'),
      );
    }

    final DateTime nowUtc = _clock.nowUtc();
    final Wish? existing = request.existing;
    if (existing == null) {
      return _repository.create(
        Wish(
          id: _idGenerator.nextId(),
          name: name,
          description: description,
          areaId: areaId,
          kind: request.kind,
          priority: request.priority,
          priceMinor: request.priceMinor,
          createdAtUtc: nowUtc,
          updatedAtUtc: nowUtc,
          rowVersion: 1,
        ),
      );
    }
    if (existing.isPurchased) {
      return const Failure<Wish>(
        ConflictFailure('Un deseo comprado ya no se edita.'),
      );
    }
    if (existing.isArchived) {
      return const Failure<Wish>(
        ConflictFailure('Restaura el deseo antes de editarlo.'),
      );
    }
    return _repository.update(
      Wish(
        id: existing.id,
        name: name,
        description: description,
        areaId: areaId,
        kind: request.kind,
        priority: request.priority,
        priceMinor: request.priceMinor,
        createdAtUtc: existing.createdAtUtc,
        updatedAtUtc: nowUtc,
        rowVersion: existing.rowVersion,
      ),
    );
  }

  /// «Eliminar» un deseo: se archiva y se puede restaurar.
  Future<Result<Wish>> archive(Wish wish) =>
      _repository.archive(wish, atUtc: _clock.nowUtc());

  Future<Result<Wish>> restore(Wish wish) =>
      _repository.restore(wish, atUtc: _clock.nowUtc());

  /// Registra el gasto en Economía y marca el deseo como comprado, todo o
  /// nada (ADR-006 D1 y D17). No toca el XP.
  Future<Result<Wish>> purchase(PurchaseWishRequest request) async {
    final Wish wish = request.wish;
    if (request.amountMinor <= 0) {
      return const Failure<Wish>(
        ValidationFailure('El precio pagado debe ser mayor que cero.'),
      );
    }
    if (wish.isPurchased) {
      return const Failure<Wish>(
        ConflictFailure('Este deseo ya está comprado.'),
      );
    }
    if (wish.isArchived) {
      return const Failure<Wish>(
        ConflictFailure('Restaura el deseo antes de comprarlo.'),
      );
    }
    final DateTime nowUtc = _clock.nowUtc();
    return _repository.purchase(
      wish,
      expense: EconomyTransaction(
        id: _idGenerator.nextId(),
        operationId: _idGenerator.nextId(),
        type: EconomyTransactionType.expense,
        amountMinor: request.amountMinor,
        paymentMethod: request.paymentMethod,
        category: purchaseCategory,
        note: wish.name,
        occurredAtUtc: nowUtc,
        createdAtUtc: nowUtc,
      ),
    );
  }

  static String? _blankToNull(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
