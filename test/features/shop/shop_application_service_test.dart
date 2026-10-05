import 'package:bitacora_rpg_personal/core/errors/app_failure.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/economy/application/economy_application_service.dart';
import 'package:bitacora_rpg_personal/features/economy/data/drift_economy_repository.dart';
import 'package:bitacora_rpg_personal/features/economy/domain/models/economy_models.dart';
import 'package:bitacora_rpg_personal/features/shop/application/shop_application_service.dart';
import 'package:bitacora_rpg_personal/features/shop/data/drift_wish_repository.dart';
import 'package:bitacora_rpg_personal/features/shop/domain/models/wish.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart'
    show AppDatabase;
import 'package:bitacora_rpg_personal/infrastructure/database/daos/economy_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/daos/wish_dao.dart';
import 'package:bitacora_rpg_personal/infrastructure/database/default_seed_v1.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _nowUtc = DateTime.utc(2026, 10, 5, 12);

void main() {
  late AppDatabase database;
  late ShopApplicationService shop;
  late DriftEconomyRepository economy;

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(),
      utcNowMilliseconds: () => _nowUtc.millisecondsSinceEpoch,
    );
    shop = ShopApplicationService(
      repository: DriftWishRepository(WishDao(database)),
      clock: const _Clock(),
      idGenerator: _Ids(),
    );
    economy = DriftEconomyRepository(EconomyDao(database));
  });

  tearDown(() => database.close());

  Future<Wish> createWish({String name = 'Monitor 27"', int? price}) async =>
      _value(
        await shop.save(
          SaveWishRequest(
            name: name,
            kind: WishKind.technology,
            areaId: DefaultSeedV1.studiesAreaId,
            priceMinor: price,
          ),
        ),
      );

  group('guardar', () {
    test('crea con prioridad media por defecto y textos recortados', () async {
      final Wish wish = _value(
        await shop.save(
          const SaveWishRequest(
            name: '  Monitor 27"  ',
            description: '   ',
            kind: WishKind.technology,
            areaId: DefaultSeedV1.studiesAreaId,
            priceMinor: 120000,
          ),
        ),
      );

      expect(wish.name, 'Monitor 27"');
      expect(wish.description, isNull);
      expect(wish.priority, WishPriority.medium);
      expect(wish.kind, WishKind.technology);
      expect(wish.areaId, DefaultSeedV1.studiesAreaId);
      expect(wish.priceMinor, 120000);
      expect(wish.rowVersion, 1);
      expect(wish.isPurchased, isFalse);
    });

    test('rechaza nombre vacío, nombre largo y precio no positivo', () async {
      final List<SaveWishRequest> invalid = <SaveWishRequest>[
        const SaveWishRequest(name: '  ', kind: WishKind.other),
        SaveWishRequest(name: 'x' * 121, kind: WishKind.other),
        const SaveWishRequest(
          name: 'Gorra',
          kind: WishKind.clothing,
          priceMinor: 0,
        ),
        SaveWishRequest(
          name: 'Libro',
          kind: WishKind.book,
          description: 'x' * 4001,
        ),
      ];
      for (final SaveWishRequest request in invalid) {
        expect(
          (await shop.save(
            request,
          )).fold(onSuccess: (_) => null, onFailure: (failure) => failure),
          isA<ValidationFailure>(),
          reason: request.name,
        );
      }
      expect(await database.select(database.inventoryItems).get(), isEmpty);
    });

    test('edita y una versión vieja es un conflicto', () async {
      final Wish created = await createWish(price: 120000);

      final Wish edited = _value(
        await shop.save(
          SaveWishRequest(
            existing: created,
            name: 'Monitor 32"',
            kind: WishKind.technology,
            priority: WishPriority.high,
            priceMinor: 150000,
          ),
        ),
      );
      expect(edited.name, 'Monitor 32"');
      expect(edited.priority, WishPriority.high);
      expect(edited.areaId, isNull);
      expect(edited.rowVersion, 2);

      final Result<Wish> stale = await shop.save(
        SaveWishRequest(
          existing: created,
          name: 'Otro',
          kind: WishKind.technology,
        ),
      );
      expect(_failure(stale), isA<ConflictFailure>());
    });

    test('archivar y restaurar', () async {
      final Wish created = await createWish();

      final Wish archived = _value(await shop.archive(created));
      expect(archived.isArchived, isTrue);
      expect(
        _failure(
          await shop.save(
            SaveWishRequest(
              existing: archived,
              name: 'Otro',
              kind: WishKind.other,
            ),
          ),
        ),
        isA<ConflictFailure>(),
      );

      final Wish restored = _value(await shop.restore(archived));
      expect(restored.isArchived, isFalse);
    });
  });

  group('comprar', () {
    test('registra el gasto en Economía y lo marca como comprado', () async {
      final Wish wish = await createWish(price: 120000);

      final Wish purchased = _value(
        await shop.purchase(
          PurchaseWishRequest(
            wish: wish,
            amountMinor: 115000,
            paymentMethod: EconomyPaymentMethod.bank,
          ),
        ),
      );

      expect(purchased.isPurchased, isTrue);
      expect(purchased.purchasedAtUtc, _nowUtc);
      expect(purchased.priority, isNull);
      final EconomyTransaction? expense = _value(
        await economy.findTransaction(purchased.purchaseTransactionId!),
      );
      expect(expense!.type, EconomyTransactionType.expense);
      expect(expense.amountMinor, 115000);
      expect(expense.paymentMethod, EconomyPaymentMethod.bank);
      expect(expense.category, ShopApplicationService.purchaseCategory);
      expect(expense.note, 'Monitor 27"');
      // No toca el XP (ADR-006 D1).
      expect(await database.select(database.xpTransactions).get(), isEmpty);
    });

    test('pulsar dos veces no duplica la compra', () async {
      final Wish wish = await createWish(price: 120000);
      final PurchaseWishRequest request = PurchaseWishRequest(
        wish: wish,
        amountMinor: 120000,
        paymentMethod: EconomyPaymentMethod.cash,
      );

      final List<Result<Wish>> results = await Future.wait(
        <Future<Result<Wish>>>[shop.purchase(request), shop.purchase(request)],
      );

      expect(results.whereType<Success<Wish>>(), hasLength(1));
      expect(
        _failure(results.whereType<Failure<Wish>>().single),
        isA<ConflictFailure>(),
      );
      expect(await database.select(database.transactions).get(), hasLength(1));
    });

    test(
      'rechaza precio no positivo, comprado y archivado sin gasto',
      () async {
        final Wish wish = await createWish();
        expect(
          _failure(
            await shop.purchase(
              PurchaseWishRequest(
                wish: wish,
                amountMinor: 0,
                paymentMethod: EconomyPaymentMethod.cash,
              ),
            ),
          ),
          isA<ValidationFailure>(),
        );

        final Wish archived = _value(await shop.archive(wish));
        expect(
          _failure(
            await shop.purchase(
              PurchaseWishRequest(
                wish: archived,
                amountMinor: 1000,
                paymentMethod: EconomyPaymentMethod.cash,
              ),
            ),
          ),
          isA<ConflictFailure>(),
        );
        expect(await database.select(database.transactions).get(), isEmpty);
      },
    );
  });
}

T _value<T>(Result<T> result) => result.fold(
  onSuccess: (T value) => value,
  onFailure: (failure) => throw failure,
);

AppFailure _failure<T>(Result<T> result) => result.fold(
  onSuccess: (_) => throw StateError('Se esperaba un fallo.'),
  onFailure: (failure) => failure,
);

final class _Clock implements EconomyClock {
  const _Clock();

  @override
  DateTime nowUtc() => _nowUtc;
}

final class _Ids implements EconomyIdGenerator {
  int _next = 0;

  @override
  String nextId() => 'id-${_next++}';
}
