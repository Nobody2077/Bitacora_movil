import 'package:drift/drift.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../../../infrastructure/database/app_database.dart' as drift;
import '../../../infrastructure/database/daos/dao_support.dart';
import '../../../infrastructure/database/daos/wish_dao.dart';
import '../../economy/data/drift_economy_repository.dart';
import '../../economy/domain/models/economy_models.dart';
import '../domain/models/wish.dart';
import '../domain/repositories/wish_repository.dart';

final class DriftWishRepository implements WishRepository {
  const DriftWishRepository(this._dao);

  final WishDao _dao;

  @override
  Stream<Result<List<Wish>>> watchActive() =>
      _watchList(_dao.watchActive(), 'No se pudieron leer los deseos.');

  @override
  Stream<Result<List<Wish>>> watchArchived() => _watchList(
    _dao.watchArchived(),
    'No se pudieron leer los deseos archivados.',
  );

  @override
  Stream<Result<List<Wish>>> watchPurchased() => _watchList(
    _dao.watchPurchased(),
    'No se pudieron leer los deseos comprados.',
  );

  @override
  Stream<Result<Wish?>> watchById(String id) async* {
    if (id.trim().isEmpty) {
      yield const Failure<Wish?>(
        ValidationFailure('El identificador del deseo es obligatorio.'),
      );
      return;
    }
    try {
      await for (final drift.InventoryItem? row in _dao.watchById(id)) {
        yield Success<Wish?>(row == null ? null : fromDrift(row));
      }
    } on Object catch (error) {
      yield Failure<Wish?>(
        StorageFailure('No se pudo leer el deseo.', cause: error),
      );
    }
  }

  @override
  Future<Result<Wish>> create(Wish wish) async {
    final ValidationFailure? invalid = _validate(wish);
    if (invalid != null) {
      return Failure<Wish>(invalid);
    }
    try {
      final DaoWriteResult<drift.InventoryItem> written = await _dao.insertWish(
        drift.InventoryItemsCompanion.insert(
          id: wish.id,
          name: wish.name,
          description: Value<String?>(wish.description),
          category: kindToken(wish.kind),
          iconKey: kindToken(wish.kind).toLowerCase(),
          status: WishDao.wishedStatus,
          areaId: Value<String?>(wish.areaId),
          wishPriority: Value<String?>(_priorityToken(wish.priority!)),
          wishPriceMinor: Value<int?>(wish.priceMinor),
          createdAt: wish.createdAtUtc.millisecondsSinceEpoch,
          updatedAt: wish.updatedAtUtc.millisecondsSinceEpoch,
        ),
      );
      return Success<Wish>(fromDrift(written.value));
    } on IdempotencyConflictException {
      return const Failure<Wish>(
        ConflictFailure('Ya existe otro deseo con ese identificador.'),
      );
    } on Object catch (error) {
      return Failure<Wish>(
        StorageFailure('No se pudo crear el deseo.', cause: error),
      );
    }
  }

  @override
  Future<Result<Wish>> update(Wish wish) async {
    final ValidationFailure? invalid = _validate(wish);
    if (invalid != null) {
      return Failure<Wish>(invalid);
    }
    return _write(
      () => _dao.updateWish(
        wishId: wish.id,
        expectedRowVersion: wish.rowVersion,
        changes: drift.InventoryItemsCompanion(
          name: Value<String>(wish.name),
          description: Value<String?>(wish.description),
          category: Value<String>(kindToken(wish.kind)),
          iconKey: Value<String>(kindToken(wish.kind).toLowerCase()),
          areaId: Value<String?>(wish.areaId),
          wishPriority: Value<String?>(_priorityToken(wish.priority!)),
          wishPriceMinor: Value<int?>(wish.priceMinor),
          updatedAt: Value<int>(wish.updatedAtUtc.millisecondsSinceEpoch),
        ),
      ),
      'No se pudo guardar el deseo.',
    );
  }

  @override
  Future<Result<Wish>> archive(Wish wish, {required DateTime atUtc}) async {
    if (!atUtc.isUtc) {
      return const Failure<Wish>(
        ValidationFailure('El instante de archivo no es válido.'),
      );
    }
    return _write(
      () => _dao.archiveWish(
        wishId: wish.id,
        expectedRowVersion: wish.rowVersion,
        archivedAtUtcMs: atUtc.millisecondsSinceEpoch,
      ),
      'No se pudo archivar el deseo.',
    );
  }

  @override
  Future<Result<Wish>> restore(Wish wish, {required DateTime atUtc}) async {
    if (!atUtc.isUtc) {
      return const Failure<Wish>(
        ValidationFailure('El instante de restauración no es válido.'),
      );
    }
    return _write(
      () => _dao.restoreWish(
        wishId: wish.id,
        expectedRowVersion: wish.rowVersion,
        updatedAtUtcMs: atUtc.millisecondsSinceEpoch,
      ),
      'No se pudo restaurar el deseo.',
    );
  }

  @override
  Future<Result<Wish>> purchase(
    Wish wish, {
    required EconomyTransaction expense,
  }) async {
    if (expense.type != EconomyTransactionType.expense ||
        expense.amountMinor <= 0 ||
        expense.paymentMethod == null ||
        !expense.occurredAtUtc.isUtc ||
        !expense.createdAtUtc.isUtc) {
      return const Failure<Wish>(
        ValidationFailure('El gasto de la compra no es válido.'),
      );
    }
    return _write(
      () async => (await _dao.purchaseWish(
        wishId: wish.id,
        expectedRowVersion: wish.rowVersion,
        expense: DriftEconomyRepository.ledgerInputOf(expense),
      )).value.item,
      'No se pudo registrar la compra.',
      alreadyMessage: 'Este deseo ya está comprado o archivado.',
    );
  }

  static Wish fromDrift(drift.InventoryItem row) => Wish(
    id: row.id,
    name: row.name,
    description: row.description,
    areaId: row.areaId,
    kind: _kind(row.category),
    priority: row.wishPriority == null ? null : _priority(row.wishPriority!),
    priceMinor: row.wishPriceMinor,
    createdAtUtc: _utc(row.createdAt),
    updatedAtUtc: _utc(row.updatedAt),
    archivedAtUtc: row.archivedAt == null ? null : _utc(row.archivedAt!),
    purchasedAtUtc: row.purchaseTransactionId == null || row.acquiredAt == null
        ? null
        : _utc(row.acquiredAt!),
    purchaseTransactionId: row.purchaseTransactionId,
    rowVersion: row.rowVersion,
  );

  /// Valor de `inventory_items.category` para cada tipo.
  static String kindToken(WishKind kind) => switch (kind) {
    WishKind.technology => 'TECHNOLOGY',
    WishKind.clothing => 'CLOTHING',
    WishKind.accessory => 'ACCESSORY',
    WishKind.book => 'BOOK',
    WishKind.part => 'PART',
    WishKind.home => 'HOME',
    WishKind.other => 'OTHER',
  };

  static WishKind _kind(String value) => switch (value) {
    'TECHNOLOGY' => WishKind.technology,
    'CLOTHING' => WishKind.clothing,
    'ACCESSORY' => WishKind.accessory,
    'BOOK' => WishKind.book,
    'PART' => WishKind.part,
    'HOME' => WishKind.home,
    'OTHER' => WishKind.other,
    _ => throw StateError('Unknown item category.'),
  };

  static String _priorityToken(WishPriority priority) => switch (priority) {
    WishPriority.low => 'LOW',
    WishPriority.medium => 'MEDIUM',
    WishPriority.high => 'HIGH',
  };

  static WishPriority _priority(String value) => switch (value) {
    'LOW' => WishPriority.low,
    'MEDIUM' => WishPriority.medium,
    'HIGH' => WishPriority.high,
    _ => throw StateError('Unknown wish priority.'),
  };

  Future<Result<Wish>> _write(
    Future<drift.InventoryItem> Function() action,
    String failureMessage, {
    String alreadyMessage = 'El deseo ya estaba en ese estado.',
  }) async {
    try {
      return Success<Wish>(fromDrift(await action()));
    } on OptimisticLockException {
      return const Failure<Wish>(
        ConflictFailure(
          'El deseo cambió en otro lugar. Vuelve a abrirlo antes de guardar.',
        ),
      );
    } on RecordNotFoundException {
      return const Failure<Wish>(
        ConflictFailure('El deseo ya no está disponible.'),
      );
    } on DatabaseInvariantException {
      return Failure<Wish>(ConflictFailure(alreadyMessage));
    } on IdempotencyConflictException {
      return const Failure<Wish>(
        ConflictFailure('La compra choca con otro movimiento ya registrado.'),
      );
    } on Object catch (error) {
      return Failure<Wish>(StorageFailure(failureMessage, cause: error));
    }
  }

  static Stream<Result<List<Wish>>> _watchList(
    Stream<List<drift.InventoryItem>> rows,
    String failureMessage,
  ) async* {
    try {
      await for (final List<drift.InventoryItem> batch in rows) {
        yield Success<List<Wish>>(batch.map(fromDrift).toList(growable: false));
      }
    } on Object catch (error) {
      yield Failure<List<Wish>>(StorageFailure(failureMessage, cause: error));
    }
  }

  static ValidationFailure? _validate(Wish wish) {
    final int nameLength = wish.name.trim().length;
    if (wish.id.trim().isEmpty ||
        nameLength < 1 ||
        nameLength > Wish.maxNameLength ||
        wish.priority == null ||
        (wish.priceMinor != null && wish.priceMinor! <= 0) ||
        (wish.description != null &&
            wish.description!.length > Wish.maxDescriptionLength) ||
        !wish.createdAtUtc.isUtc ||
        !wish.updatedAtUtc.isUtc ||
        wish.rowVersion < 1) {
      return const ValidationFailure('El deseo contiene valores inválidos.');
    }
    return null;
  }

  static DateTime _utc(int milliseconds) =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
}
