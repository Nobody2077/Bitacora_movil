import 'package:drift/drift.dart';

import '../app_database.dart';
import 'dao_support.dart';
import 'economy_dao.dart';

/// Lista de deseos de la Tienda (ADR-006 D17) sobre `inventory_items`.
///
/// Un deseo es una fila con `status = 'WISHED'`; comprarlo la pasa a
/// `OWNED` con `origin = 'PURCHASE'` en la misma transacción que escribe su
/// gasto. Nunca borra: eliminar un deseo es archivarlo.
final class WishDao {
  WishDao(this._database) : _economyDao = EconomyDao(_database);

  final AppDatabase _database;
  final EconomyDao _economyDao;

  static const String wishedStatus = 'WISHED';
  static const String ownedStatus = 'OWNED';
  static const String purchaseOrigin = 'PURCHASE';
  static const String expenseType = 'EXPENSE';

  Future<InventoryItem?> findById(String id) {
    return (_database.select(
      _database.inventoryItems,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Stream<InventoryItem?> watchById(String id) {
    return (_database.select(
      _database.inventoryItems,
    )..where((table) => table.id.equals(id))).watchSingleOrNull();
  }

  /// Deseos activos: prioridad alta primero y, dentro de cada prioridad, el
  /// más reciente arriba.
  Stream<List<InventoryItem>> watchActive() {
    return (_database.select(_database.inventoryItems)
          ..where(
            (table) =>
                table.status.equals(wishedStatus) & table.archivedAt.isNull(),
          )
          ..orderBy(<OrderingTerm Function(InventoryItems)>[
            (table) => OrderingTerm.asc(_priorityRank(table)),
            (table) => OrderingTerm.desc(table.createdAt),
            (table) => OrderingTerm.asc(table.id),
          ]))
        .watch();
  }

  Stream<List<InventoryItem>> watchArchived() {
    return (_database.select(_database.inventoryItems)
          ..where(
            (table) =>
                table.status.equals(wishedStatus) &
                table.archivedAt.isNotNull(),
          )
          ..orderBy(<OrderingTerm Function(InventoryItems)>[
            (table) => OrderingTerm.desc(table.archivedAt),
            (table) => OrderingTerm.asc(table.id),
          ]))
        .watch();
  }

  /// Deseos ya comprados desde la Tienda, del más reciente al más antiguo.
  Stream<List<InventoryItem>> watchPurchased() {
    return (_database.select(_database.inventoryItems)
          ..where(
            (table) =>
                table.status.equals(ownedStatus) &
                table.origin.equals(purchaseOrigin) &
                table.purchaseTransactionId.isNotNull(),
          )
          ..orderBy(<OrderingTerm Function(InventoryItems)>[
            (table) => OrderingTerm.desc(table.acquiredAt),
            (table) => OrderingTerm.asc(table.id),
          ]))
        .watch();
  }

  /// Deseos activos con precio que el saldo disponible ya alcanza, para el
  /// resumen diario (ADR-006 D17). Las metas vinculadas no cuentan.
  Future<int> countAffordable(int availableMinor) async {
    final Expression<int> count = _database.inventoryItems.id.count();
    final TypedResult row =
        await (_database.selectOnly(_database.inventoryItems)
              ..addColumns(<Expression<Object>>[count])
              ..where(
                _database.inventoryItems.status.equals(wishedStatus) &
                    _database.inventoryItems.archivedAt.isNull() &
                    _database.inventoryItems.wishPriceMinor.isNotNull() &
                    _database.inventoryItems.wishPriceMinor
                        .isSmallerOrEqualValue(availableMinor),
              ))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// Inserta un deseo con un id generado por el cliente.
  ///
  /// Repetir la misma inserción es idempotente y devuelve la fila existente
  /// con `created: false`; el mismo id con datos distintos es un conflicto.
  Future<DaoWriteResult<InventoryItem>> insertWish(
    InventoryItemsCompanion wish,
  ) {
    if (!wish.id.present) {
      throw ArgumentError('Wish id must be present.');
    }
    if (wish.status.present && wish.status.value != wishedStatus) {
      throw ArgumentError('A new wish must have status WISHED.');
    }
    if (wish.rowVersion.present ||
        wish.archivedAt.present ||
        wish.origin.present ||
        wish.acquiredAt.present ||
        wish.purchaseTransactionId.present) {
      throw ArgumentError(
        'row_version, archived_at and purchase fields are set by WishDao.',
      );
    }
    final String id = wish.id.value;
    return _database.transaction(() async {
      final InventoryItem? existing = await findById(id);
      if (existing != null) {
        if (_sameContent(existing, wish)) {
          return DaoWriteResult<InventoryItem>(value: existing, created: false);
        }
        throw IdempotencyConflictException(operationId: id, entity: 'wish');
      }
      await _database
          .into(_database.inventoryItems)
          .insert(wish.copyWith(status: const Value<String>(wishedStatus)));
      return DaoWriteResult<InventoryItem>(
        value: await _require(id),
        created: true,
      );
    });
  }

  /// Cambia los datos de un deseo activo con bloqueo optimista.
  Future<InventoryItem> updateWish({
    required String wishId,
    required int expectedRowVersion,
    required InventoryItemsCompanion changes,
  }) {
    if (changes.id.present ||
        changes.status.present ||
        changes.rowVersion.present ||
        changes.archivedAt.present ||
        changes.createdAt.present ||
        changes.origin.present ||
        changes.acquiredAt.present ||
        changes.purchaseTransactionId.present) {
      throw ArgumentError(
        'id, status, created_at, archived_at, row_version and purchase '
        'fields are set by WishDao.',
      );
    }
    return _database.transaction(() async {
      final InventoryItem current = await _requireWish(wishId);
      if (current.archivedAt != null) {
        throw DatabaseInvariantException('Wish $wishId is archived.');
      }
      return _writeWithRowVersion(
        wishId: wishId,
        expectedRowVersion: expectedRowVersion,
        changes: changes,
      );
    });
  }

  Future<InventoryItem> archiveWish({
    required String wishId,
    required int expectedRowVersion,
    required int archivedAtUtcMs,
  }) {
    return _database.transaction(() async {
      final InventoryItem current = await _requireWish(wishId);
      if (current.archivedAt != null) {
        throw DatabaseInvariantException('Wish $wishId is archived.');
      }
      return _writeWithRowVersion(
        wishId: wishId,
        expectedRowVersion: expectedRowVersion,
        changes: InventoryItemsCompanion(
          archivedAt: Value<int?>(archivedAtUtcMs),
          updatedAt: Value<int>(archivedAtUtcMs),
        ),
      );
    });
  }

  Future<InventoryItem> restoreWish({
    required String wishId,
    required int expectedRowVersion,
    required int updatedAtUtcMs,
  }) {
    return _database.transaction(() async {
      final InventoryItem current = await _requireWish(wishId);
      if (current.archivedAt == null) {
        throw DatabaseInvariantException('Wish $wishId is not archived.');
      }
      return _writeWithRowVersion(
        wishId: wishId,
        expectedRowVersion: expectedRowVersion,
        changes: InventoryItemsCompanion(
          archivedAt: const Value<int?>(null),
          updatedAt: Value<int>(updatedAtUtcMs),
        ),
      );
    });
  }

  /// Compra un deseo: escribe el gasto y pasa el deseo a comprado, todo o
  /// nada (ADR-006 D1 y D17).
  ///
  /// Repetir la misma compra (mismo `operation_id`) devuelve el resultado
  /// existente con `created: false`. Un deseo ya comprado con otro gasto, o
  /// archivado, es un [DatabaseInvariantException].
  Future<DaoWriteResult<WishPurchase>> purchaseWish({
    required String wishId,
    required int expectedRowVersion,
    required LedgerTransactionInput expense,
  }) {
    if (expense.transactionType != expenseType) {
      throw ArgumentError('A purchase must be written as an EXPENSE.');
    }
    if (expense.relatedTransactionId != null || expense.missionId != null) {
      throw ArgumentError('A purchase cannot be linked to other records.');
    }
    return _database.transaction(() async {
      final InventoryItem current = await _require(wishId);
      if (current.status == ownedStatus &&
          current.purchaseTransactionId != null) {
        final Transaction? previous = await _economyDao.findTransaction(
          current.purchaseTransactionId!,
        );
        if (previous != null && previous.operationId == expense.operationId) {
          return DaoWriteResult<WishPurchase>(
            value: WishPurchase(item: current, transaction: previous),
            created: false,
          );
        }
        throw DatabaseInvariantException('Wish $wishId is already purchased.');
      }
      if (current.status != wishedStatus) {
        throw RecordNotFoundException(table: 'wishes', key: wishId);
      }
      if (current.archivedAt != null) {
        throw DatabaseInvariantException('Wish $wishId is archived.');
      }

      final DaoWriteResult<Transaction> written = await _economyDao
          .writeTransaction(expense);
      final InventoryItem purchased = await _writeWithRowVersion(
        wishId: wishId,
        expectedRowVersion: expectedRowVersion,
        changes: InventoryItemsCompanion(
          status: const Value<String>(ownedStatus),
          origin: const Value<String?>(purchaseOrigin),
          wishPriority: const Value<String?>(null),
          acquiredAt: Value<int?>(expense.occurredAtUtcMs),
          purchaseTransactionId: Value<String?>(written.value.id),
          updatedAt: Value<int>(expense.createdAtUtcMs),
        ),
      );
      return DaoWriteResult<WishPurchase>(
        value: WishPurchase(item: purchased, transaction: written.value),
        created: true,
      );
    });
  }

  Future<InventoryItem> _writeWithRowVersion({
    required String wishId,
    required int expectedRowVersion,
    required InventoryItemsCompanion changes,
  }) async {
    if (expectedRowVersion < 1) {
      throw ArgumentError.value(expectedRowVersion, 'expectedRowVersion');
    }
    final int affected =
        await (_database.update(_database.inventoryItems)..where(
              (table) =>
                  table.id.equals(wishId) &
                  table.rowVersion.equals(expectedRowVersion),
            ))
            .write(
              changes.copyWith(rowVersion: Value<int>(expectedRowVersion + 1)),
            );
    if (affected != 1) {
      if (await findById(wishId) == null) {
        throw RecordNotFoundException(table: 'wishes', key: wishId);
      }
      throw OptimisticLockException(
        table: 'wishes',
        id: wishId,
        expectedRowVersion: expectedRowVersion,
      );
    }
    return _require(wishId);
  }

  /// Un deseo, no un objeto ya comprado ni otra fila de `inventory_items`.
  Future<InventoryItem> _requireWish(String wishId) async {
    final InventoryItem item = await _require(wishId);
    if (item.status != wishedStatus) {
      throw RecordNotFoundException(table: 'wishes', key: wishId);
    }
    return item;
  }

  Future<InventoryItem> _require(String wishId) async {
    final InventoryItem? item = await findById(wishId);
    if (item == null) {
      throw RecordNotFoundException(table: 'wishes', key: wishId);
    }
    return item;
  }

  static Expression<int> _priorityRank(InventoryItems table) =>
      table.wishPriority.caseMatch<int>(
        when: <Expression<String>, Expression<int>>{
          const Constant<String>('HIGH'): const Constant<int>(0),
          const Constant<String>('MEDIUM'): const Constant<int>(1),
        },
        orElse: const Constant<int>(2),
      );

  static bool _sameContent(
    InventoryItem existing,
    InventoryItemsCompanion incoming,
  ) =>
      existing.status == wishedStatus &&
      existing.archivedAt == null &&
      existing.name == incoming.name.value &&
      existing.description ==
          (incoming.description.present ? incoming.description.value : null) &&
      existing.category == incoming.category.value &&
      existing.iconKey == incoming.iconKey.value &&
      existing.areaId ==
          (incoming.areaId.present ? incoming.areaId.value : null) &&
      existing.wishPriority ==
          (incoming.wishPriority.present
              ? incoming.wishPriority.value
              : null) &&
      existing.wishPriceMinor ==
          (incoming.wishPriceMinor.present
              ? incoming.wishPriceMinor.value
              : null);
}

/// Resultado de comprar un deseo: el objeto ya comprado y su gasto.
final class WishPurchase {
  const WishPurchase({required this.item, required this.transaction});

  final InventoryItem item;
  final Transaction transaction;
}
