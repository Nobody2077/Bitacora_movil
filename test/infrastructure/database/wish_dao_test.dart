import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/dao_support.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/economy_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/wish_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/default_seed_v1.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const int _now = 1790000000000;

void main() {
  late AppDatabase database;
  late WishDao wishes;

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => _now,
    );
    wishes = WishDao(database);
  });

  tearDown(() => database.close());

  Future<int> transactionCount() async =>
      (await database.select(database.transactions).get()).length;

  group('deseos', () {
    test('repetir la misma inserción es idempotente', () async {
      final first = await wishes.insertWish(_wish('w1'));
      final retried = await wishes.insertWish(_wish('w1'));

      expect(first.created, isTrue);
      expect(first.value.status, 'WISHED');
      expect(first.value.areaId, DefaultSeedV1.homeAreaId);
      expect(retried.created, isFalse);
      expect(
        await database.select(database.inventoryItems).get(),
        hasLength(1),
      );
    });

    test('el mismo id con otros datos es un conflicto', () async {
      await wishes.insertWish(_wish('w1'));

      await expectLater(
        wishes.insertWish(_wish('w1', name: 'Otra cosa')),
        throwsA(isA<IdempotencyConflictException>()),
      );
    });

    test('editar exige la versión vigente', () async {
      await wishes.insertWish(_wish('w1'));

      final updated = await wishes.updateWish(
        wishId: 'w1',
        expectedRowVersion: 1,
        changes: const InventoryItemsCompanion(
          wishPriceMinor: Value<int?>(45000),
          areaId: Value<String?>(null),
          updatedAt: Value<int>(_now + 1),
        ),
      );
      expect(updated.rowVersion, 2);
      expect(updated.wishPriceMinor, 45000);
      expect(updated.areaId, isNull);

      await expectLater(
        wishes.updateWish(
          wishId: 'w1',
          expectedRowVersion: 1,
          changes: const InventoryItemsCompanion(
            name: Value<String>('Silla gamer'),
          ),
        ),
        throwsA(isA<OptimisticLockException>()),
      );
    });

    test('archivar y restaurar mueven el deseo entre listas', () async {
      await wishes.insertWish(_wish('w1'));
      await wishes.insertWish(_wish('w2', priority: 'HIGH'));

      expect((await wishes.watchActive().first).map((row) => row.id), <String>[
        'w2',
        'w1',
      ]);

      final archived = await wishes.archiveWish(
        wishId: 'w1',
        expectedRowVersion: 1,
        archivedAtUtcMs: _now + 5,
      );
      expect(archived.archivedAt, _now + 5);
      expect((await wishes.watchActive().first).map((row) => row.id), <String>[
        'w2',
      ]);
      expect(
        (await wishes.watchArchived().first).map((row) => row.id),
        <String>['w1'],
      );
      await expectLater(
        wishes.updateWish(
          wishId: 'w1',
          expectedRowVersion: 2,
          changes: const InventoryItemsCompanion(
            name: Value<String>('Silla gamer'),
          ),
        ),
        throwsA(isA<DatabaseInvariantException>()),
      );

      final restored = await wishes.restoreWish(
        wishId: 'w1',
        expectedRowVersion: 2,
        updatedAtUtcMs: _now + 6,
      );
      expect(restored.archivedAt, isNull);
      expect(await wishes.watchArchived().first, isEmpty);
    });
  });

  group('comprar', () {
    test('escribe el gasto y pasa el deseo a comprado, juntos', () async {
      await wishes.insertWish(_wish('w1'));

      final result = await wishes.purchaseWish(
        wishId: 'w1',
        expectedRowVersion: 1,
        expense: _expense('op-1', amountMinor: 38000),
      );

      expect(result.created, isTrue);
      expect(result.value.transaction.transactionType, 'EXPENSE');
      expect(result.value.transaction.amountMinor, 38000);
      expect(result.value.transaction.category, 'Tienda');
      final item = result.value.item;
      expect(item.status, 'OWNED');
      expect(item.origin, 'PURCHASE');
      expect(item.wishPriority, isNull);
      expect(item.acquiredAt, _now + 10);
      expect(item.purchaseTransactionId, result.value.transaction.id);
      expect(item.areaId, DefaultSeedV1.homeAreaId);
      expect(await wishes.watchActive().first, isEmpty);
      expect(
        (await wishes.watchPurchased().first).map((row) => row.id),
        <String>['w1'],
      );
      expect(await transactionCount(), 1);
    });

    test('repetir la misma compra no duplica el gasto', () async {
      await wishes.insertWish(_wish('w1'));
      await wishes.purchaseWish(
        wishId: 'w1',
        expectedRowVersion: 1,
        expense: _expense('op-1'),
      );

      final retried = await wishes.purchaseWish(
        wishId: 'w1',
        expectedRowVersion: 1,
        expense: _expense('op-1'),
      );

      expect(retried.created, isFalse);
      expect(retried.value.item.status, 'OWNED');
      expect(await transactionCount(), 1);
    });

    test('comprar otra vez el mismo deseo se rechaza sin gasto', () async {
      await wishes.insertWish(_wish('w1'));
      await wishes.purchaseWish(
        wishId: 'w1',
        expectedRowVersion: 1,
        expense: _expense('op-1'),
      );

      await expectLater(
        wishes.purchaseWish(
          wishId: 'w1',
          expectedRowVersion: 2,
          expense: _expense('op-2'),
        ),
        throwsA(isA<DatabaseInvariantException>()),
      );
      expect(await transactionCount(), 1);
    });

    test('si falla a mitad no queda gasto suelto ni deseo comprado', () async {
      await wishes.insertWish(_wish('w1'));
      await wishes.updateWish(
        wishId: 'w1',
        expectedRowVersion: 1,
        changes: const InventoryItemsCompanion(
          wishPriceMinor: Value<int?>(41000),
        ),
      );

      // El gasto se escribe y la versión vieja hace fallar el segundo paso.
      await expectLater(
        wishes.purchaseWish(
          wishId: 'w1',
          expectedRowVersion: 1,
          expense: _expense('op-1'),
        ),
        throwsA(isA<OptimisticLockException>()),
      );

      expect(await transactionCount(), 0);
      final item = await wishes.findById('w1');
      expect(item!.status, 'WISHED');
      expect(item.purchaseTransactionId, isNull);
      expect(item.rowVersion, 2);
    });

    test('un deseo archivado no se compra', () async {
      await wishes.insertWish(_wish('w1'));
      await wishes.archiveWish(
        wishId: 'w1',
        expectedRowVersion: 1,
        archivedAtUtcMs: _now + 5,
      );

      await expectLater(
        wishes.purchaseWish(
          wishId: 'w1',
          expectedRowVersion: 2,
          expense: _expense('op-1'),
        ),
        throwsA(isA<DatabaseInvariantException>()),
      );
      expect(await transactionCount(), 0);
    });

    test('solo acepta un gasto suelto', () async {
      await wishes.insertWish(_wish('w1'));

      expect(
        () => wishes.purchaseWish(
          wishId: 'w1',
          expectedRowVersion: 1,
          expense: _expense('op-1', type: 'INCOME'),
        ),
        throwsArgumentError,
      );
    });
  });
}

InventoryItemsCompanion _wish(
  String id, {
  String name = 'Silla ergonómica',
  String priority = 'MEDIUM',
}) => InventoryItemsCompanion.insert(
  id: id,
  name: name,
  description: const Value<String?>('Con apoyo lumbar'),
  category: 'HOME',
  iconKey: 'home',
  status: 'WISHED',
  areaId: const Value<String?>(DefaultSeedV1.homeAreaId),
  wishPriority: Value<String?>(priority),
  wishPriceMinor: const Value<int?>(40000),
  createdAt: _now,
  updatedAt: _now,
);

LedgerTransactionInput _expense(
  String operationId, {
  int amountMinor = 40000,
  String type = 'EXPENSE',
}) => LedgerTransactionInput(
  id: 'tx-$operationId',
  operationId: operationId,
  transactionType: type,
  amountMinor: amountMinor,
  paymentMethod: 'CASH',
  category: 'Tienda',
  note: 'Silla ergonómica',
  occurredAtUtcMs: _now + 10,
  createdAtUtcMs: _now + 10,
);
