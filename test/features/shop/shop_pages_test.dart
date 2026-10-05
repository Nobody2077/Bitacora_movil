import 'dart:async';

import 'package:bitacora_rpg_personal/app/providers/persistence_providers.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/app/theme/app_theme_tokens.dart';
import 'package:bitacora_rpg_personal/app/theme/app_ui_preferences.dart';
import 'package:bitacora_rpg_personal/core/errors/app_failure.dart';
import 'package:bitacora_rpg_personal/core/result/result.dart';
import 'package:bitacora_rpg_personal/features/character/presentation/character_menu_page.dart';
import 'package:bitacora_rpg_personal/features/economy/application/economy_application_service.dart';
import 'package:bitacora_rpg_personal/features/economy/application/economy_providers.dart';
import 'package:bitacora_rpg_personal/features/economy/domain/models/economy_models.dart';
import 'package:bitacora_rpg_personal/features/economy/domain/models/economy_snapshot.dart';
import 'package:bitacora_rpg_personal/features/missions/application/mission_providers.dart';
import 'package:bitacora_rpg_personal/features/missions/domain/models/mission.dart';
import 'package:bitacora_rpg_personal/features/progress/application/progress_providers.dart';
import 'package:bitacora_rpg_personal/features/progress/domain/models/progress_models.dart';
import 'package:bitacora_rpg_personal/features/progress/domain/models/rpg_level.dart';
import 'package:bitacora_rpg_personal/features/shop/application/shop_providers.dart';
import 'package:bitacora_rpg_personal/features/shop/domain/models/wish.dart';
import 'package:bitacora_rpg_personal/features/shop/domain/repositories/wish_repository.dart';
import 'package:bitacora_rpg_personal/features/shop/presentation/shop_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final DateTime _now = DateTime.utc(2026, 10, 5, 12);

void main() {
  late _WishRepository repository;
  late StreamController<EconomySnapshot> balance;

  setUp(() {
    repository = _WishRepository();
    balance = StreamController<EconomySnapshot>.broadcast();
  });

  tearDown(() => balance.close());

  Future<void> pumpMenu(
    WidgetTester tester, {
    int availableMinor = 100000,
    AppUiPreferences preferences = const AppUiPreferences.defaults(),
  }) async {
    _tabletView(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(repository, balance, availableMinor),
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: (BuildContext context, Widget? child) =>
              AppUiPreferencesBoundary(preferences: preferences, child: child!),
          home: const Scaffold(
            body: CharacterMenuPage(initialTab: CharacterTab.tienda),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('las pestañas son TIENDA, PERSONAJE y DIARIO, sin MAPA', (
    WidgetTester tester,
  ) async {
    await pumpMenu(tester);

    for (final String tab in <String>['tienda', 'personaje', 'diario']) {
      expect(
        find.byKey(ValueKey<String>('character-tab-$tab')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const ValueKey<String>('character-tab-mapa')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('character-tab-ciberware')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('character-tab-inventario')),
      findsNothing,
    );
    expect(find.text('Tu lista de deseos está vacía'), findsOneWidget);
    expect(find.byKey(const Key('wish-create')), findsOneWidget);
  });

  testWidgets('cada deseo dice con texto si te alcanza, no solo con color', (
    WidgetTester tester,
  ) async {
    repository.seed(<Wish>[
      _wish('w-ok', 'Audífonos', price: 80000, areaId: 'studies'),
      _wish('w-close', 'Monitor', price: 120000),
      _wish('w-far', 'Bicicleta', price: 200000),
      _wish('w-none', 'Libro raro'),
    ]);
    await pumpMenu(tester);

    expect(find.text('DESEOS · 4'), findsOneWidget);
    expect(_affordability('w-ok'), 'Te alcanza');
    expect(_affordability('w-close'), 'Faltan Bs 200,00');
    expect(_affordability('w-far'), 'Faltan Bs 1000,00');
    expect(_affordability('w-none'), 'Sin precio');
    expect(find.text('ESTUDIOS'), findsOneWidget);
    expect(find.text('PRIORIDAD MEDIA'), findsNWidgets(4));
  });

  testWidgets('con importes ocultos se tapa la cifra pero no la frase', (
    WidgetTester tester,
  ) async {
    repository.seed(<Wish>[_wish('w-close', 'Monitor', price: 120000)]);
    await pumpMenu(
      tester,
      preferences: const AppUiPreferences(
        largeText: false,
        reduceMotion: false,
        highContrast: false,
        hideAmounts: true,
      ),
    );

    expect(_affordability('w-close'), 'Faltan Bs •••');
    expect(find.textContaining('1200,00'), findsNothing);
    expect(find.textContaining('1000,00'), findsNothing);
  });

  testWidgets('Comprados y Archivados muestran sus listas', (
    WidgetTester tester,
  ) async {
    repository.seed(<Wish>[
      _wish('w-arch', 'Silla', archived: true),
      _wish('w-bought', 'Teclado', purchased: true),
    ]);
    await pumpMenu(tester);

    expect(find.text('Tu lista de deseos está vacía'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shop-mode-archived')));
    await tester.pumpAndSettle();
    expect(find.text('Silla'), findsOneWidget);

    await tester.tap(find.byKey(const Key('shop-mode-purchased')));
    await tester.pumpAndSettle();
    expect(find.text('Teclado'), findsOneWidget);
  });

  testWidgets('tras comprar, el saldo baja en naranja y sale «− Bs X»', (
    WidgetTester tester,
  ) async {
    await pumpMenu(tester);
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(CharacterMenuPage)),
    );

    container
        .read(purchaseFeedbackProvider.notifier)
        .announce(
          const PurchaseFeedback(
            amountMinor: 40000,
            balanceBeforeMinor: 100000,
          ),
        );
    balance.add(_snapshot(60000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('character-balance-spent')), findsOneWidget);
    expect(find.text('− Bs 400,00'), findsOneWidget);
    final Text animated = tester.widget<Text>(
      find.byKey(const Key('character-balance')),
    );
    final Color orange = AppTheme.dark()
        .extension<AppThemeTokens>()!
        .attentionOrange;
    expect(animated.style?.color, orange);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('character-balance-spent')), findsNothing);
    expect(find.text('Bs 600,00'), findsOneWidget);
    expect(container.read(purchaseFeedbackProvider), isNull);
  });

  testWidgets('con movimiento reducido el saldo cambia sin animar', (
    WidgetTester tester,
  ) async {
    await pumpMenu(
      tester,
      preferences: const AppUiPreferences(
        largeText: false,
        reduceMotion: true,
        highContrast: false,
        hideAmounts: false,
      ),
    );
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(CharacterMenuPage)),
    );

    container
        .read(purchaseFeedbackProvider.notifier)
        .announce(
          const PurchaseFeedback(
            amountMinor: 40000,
            balanceBeforeMinor: 100000,
          ),
        );
    balance.add(_snapshot(60000));
    await tester.pump();

    expect(find.byKey(const Key('character-balance-spent')), findsNothing);
    expect(find.text('Bs 600,00'), findsOneWidget);
  });

  testWidgets('añadir un deseo lleva a su ficha', (WidgetTester tester) async {
    await _pumpRouter(tester, repository, balance, '/shop/new');

    await tester.enterText(
      find.byKey(const Key('wish-name')),
      '  Monitor 27" ',
    );
    await tester.enterText(find.byKey(const Key('wish-price')), '1200,50');
    await tester.tap(find.byKey(const Key('wish-save')));
    await tester.pumpAndSettle();

    final Wish created = repository.created.single;
    expect(created.name, 'Monitor 27"');
    expect(created.priceMinor, 120050);
    expect(created.priority, WishPriority.medium);
    expect(created.kind, WishKind.other);
    expect(find.text('MONITOR 27"'), findsOneWidget);
    expect(find.byKey(const Key('wish-purchase')), findsOneWidget);
  });

  testWidgets('el nombre es obligatorio', (WidgetTester tester) async {
    await _pumpRouter(tester, repository, balance, '/shop/new');

    await tester.tap(find.byKey(const Key('wish-save')));
    await tester.pumpAndSettle();

    expect(find.text('El deseo necesita un nombre.'), findsOneWidget);
    expect(repository.created, isEmpty);
  });

  testWidgets('comprar desde la ficha registra el precio y el medio', (
    WidgetTester tester,
  ) async {
    repository.seed(<Wish>[_wish('w1', 'Monitor', price: 120000)]);
    await _pumpRouter(tester, repository, balance, '/shop/w1');

    expect(
      tester
          .widget<Text>(find.byKey(const Key('wish-detail-affordability')))
          .data,
      'Faltan Bs 200,00',
    );
    await tester.tap(find.byKey(const Key('wish-purchase')));
    await tester.pumpAndSettle();
    expect(find.text('1200,00'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('wish-purchase-amount')),
      '1150',
    );
    await tester.tap(find.byKey(const Key('wish-purchase-method')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banco').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wish-purchase-confirm')));
    await tester.pumpAndSettle();

    final ({Wish wish, EconomyTransaction expense}) purchase =
        repository.purchases.single;
    expect(purchase.expense.amountMinor, 115000);
    expect(purchase.expense.paymentMethod, EconomyPaymentMethod.bank);
    expect(purchase.expense.category, 'Tienda');
    expect(find.text('Comprado · − Bs 1150,00'), findsOneWidget);
    expect(find.text('TIENDA'), findsOneWidget);
  });

  testWidgets('eliminar archiva y restaurar lo devuelve', (
    WidgetTester tester,
  ) async {
    repository.seed(<Wish>[_wish('w1', 'Monitor', price: 120000)]);
    await _pumpRouter(tester, repository, balance, '/shop/w1');

    await tester.tap(find.byKey(const Key('wish-archive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wish-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Deseo archivado.'), findsOneWidget);
    expect(find.byKey(const Key('wish-restore')), findsOneWidget);
    expect(find.byKey(const Key('wish-purchase')), findsNothing);

    await tester.tap(find.byKey(const Key('wish-restore')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wish-purchase')), findsOneWidget);
  });
}

String? _affordability(String wishId) =>
    (find
                .byKey(ValueKey<String>('wish-affordability-$wishId'))
                .evaluate()
                .single
                .widget
            as Text)
        .data;

Future<void> _pumpRouter(
  WidgetTester tester,
  _WishRepository repository,
  StreamController<EconomySnapshot> balance,
  String location,
) async {
  _tabletView(tester);
  final GoRouter router = GoRouter(
    initialLocation: location,
    routes: <RouteBase>[
      GoRoute(
        path: '/character',
        name: 'character',
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          body: CharacterMenuPage(
            initialTab: CharacterTab.fromQuery(
              state.uri.queryParameters['tab'],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/shop/new',
        name: 'wishNew',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: WishFormPage()),
      ),
      GoRoute(
        path: '/shop/:wishId',
        name: 'wishDetail',
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          body: WishDetailPage(wishId: state.pathParameters['wishId']!),
        ),
      ),
      GoRoute(
        path: '/shop/:wishId/edit',
        name: 'wishEdit',
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          body: WishFormPage(wishId: state.pathParameters['wishId']),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(repository, balance, 100000),
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void _tabletView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1400, 1600);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

EconomySnapshot _snapshot(int availableMinor) => EconomySnapshot(
  totalMinor: availableMinor,
  reservedMinor: 0,
  monthIncomeMinor: 0,
  monthExpenseMinor: 0,
  dayIncomeMinor: 0,
  dayExpenseMinor: 0,
);

List<Override> _overrides(
  _WishRepository repository,
  StreamController<EconomySnapshot> balance,
  int availableMinor,
) => <Override>[
  wishRepositoryProvider.overrideWithValue(repository),
  economyClockProvider.overrideWithValue(const _Clock()),
  economyIdGeneratorProvider.overrideWithValue(_Ids()),
  economySnapshotProvider.overrideWith((Ref ref) async* {
    yield _snapshot(availableMinor);
    yield* balance.stream;
  }),
  economyTransactionDetailProvider.overrideWith(
    (Ref ref, String id) async => repository.expenseById(id),
  ),
  overallProgressProvider.overrideWith(
    (Ref ref) async => OverallProgressViewData(
      rpgLevel: RpgLevel.fromTotalXp(450),
      totalXp: 450,
      todayXp: 0,
      weekXp: 0,
      areaBreakdown: const <AreaProgressItem>[],
      activeTitles: const <TitleProgressItem>[],
      currentStreak: 0,
      bestStreak: 0,
    ),
  ),
  missionAreasProvider.overrideWith(
    (Ref ref) async => const <MissionArea>[
      MissionArea(
        id: 'studies',
        name: 'Estudios',
        iconKey: 'school',
        colorHex: '#55E6E6',
        isDefault: true,
      ),
    ],
  ),
];

Wish _wish(
  String id,
  String name, {
  int? price,
  String? areaId,
  bool archived = false,
  bool purchased = false,
}) => Wish(
  id: id,
  name: name,
  kind: WishKind.technology,
  priority: purchased ? null : WishPriority.medium,
  priceMinor: price,
  areaId: areaId,
  createdAtUtc: _now,
  updatedAtUtc: _now,
  archivedAtUtc: archived ? _now : null,
  purchasedAtUtc: purchased ? _now : null,
  purchaseTransactionId: purchased ? 'tx-$id' : null,
  rowVersion: 1,
);

/// Repositorio en memoria: cada cambio vuelve a emitir las tres listas.
final class _WishRepository implements WishRepository {
  final Map<String, Wish> _wishes = <String, Wish>{};
  final Map<String, EconomyTransaction> _expenses =
      <String, EconomyTransaction>{};
  final List<Wish> created = <Wish>[];
  final List<({Wish wish, EconomyTransaction expense})> purchases =
      <({Wish wish, EconomyTransaction expense})>[];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  void seed(List<Wish> wishes) {
    for (final Wish wish in wishes) {
      _wishes[wish.id] = wish;
    }
  }

  EconomyTransaction? expenseById(String id) => _expenses[id];

  Stream<Result<T>> _watch<T>(T Function() read) async* {
    yield Success<T>(read());
    yield* _changes.stream.map((_) => Success<T>(read()));
  }

  List<Wish> _where(bool Function(Wish wish) test) =>
      _wishes.values.where(test).toList(growable: false);

  @override
  Stream<Result<List<Wish>>> watchActive() =>
      _watch(() => _where((Wish w) => !w.isArchived && !w.isPurchased));

  @override
  Stream<Result<List<Wish>>> watchArchived() =>
      _watch(() => _where((Wish w) => w.isArchived && !w.isPurchased));

  @override
  Stream<Result<List<Wish>>> watchPurchased() =>
      _watch(() => _where((Wish w) => w.isPurchased));

  @override
  Stream<Result<Wish?>> watchById(String id) => _watch(() => _wishes[id]);

  void _put(Wish wish) {
    _wishes[wish.id] = wish;
    _changes.add(null);
  }

  @override
  Future<Result<Wish>> create(Wish wish) async {
    created.add(wish);
    _put(wish);
    return Success<Wish>(wish);
  }

  @override
  Future<Result<Wish>> update(Wish wish) async {
    final Wish saved = _copy(wish, rowVersion: wish.rowVersion + 1);
    _put(saved);
    return Success<Wish>(saved);
  }

  @override
  Future<Result<Wish>> archive(Wish wish, {required DateTime atUtc}) async {
    final Wish saved = _copy(
      wish,
      rowVersion: wish.rowVersion + 1,
      archivedAtUtc: atUtc,
    );
    _put(saved);
    return Success<Wish>(saved);
  }

  @override
  Future<Result<Wish>> restore(Wish wish, {required DateTime atUtc}) async {
    final Wish saved = _copy(wish, rowVersion: wish.rowVersion + 1);
    _put(saved);
    return Success<Wish>(saved);
  }

  @override
  Future<Result<Wish>> purchase(
    Wish wish, {
    required EconomyTransaction expense,
  }) async {
    if (wish.isPurchased) {
      return const Failure<Wish>(ConflictFailure('Ya comprado.'));
    }
    purchases.add((wish: wish, expense: expense));
    _expenses[expense.id] = expense;
    final Wish saved = Wish(
      id: wish.id,
      name: wish.name,
      description: wish.description,
      areaId: wish.areaId,
      kind: wish.kind,
      priceMinor: wish.priceMinor,
      createdAtUtc: wish.createdAtUtc,
      updatedAtUtc: expense.createdAtUtc,
      purchasedAtUtc: expense.occurredAtUtc,
      purchaseTransactionId: expense.id,
      rowVersion: wish.rowVersion + 1,
    );
    _put(saved);
    return Success<Wish>(saved);
  }

  static Wish _copy(
    Wish wish, {
    required int rowVersion,
    DateTime? archivedAtUtc,
  }) => Wish(
    id: wish.id,
    name: wish.name,
    description: wish.description,
    areaId: wish.areaId,
    kind: wish.kind,
    priority: wish.priority,
    priceMinor: wish.priceMinor,
    createdAtUtc: wish.createdAtUtc,
    updatedAtUtc: wish.updatedAtUtc,
    archivedAtUtc: archivedAtUtc,
    rowVersion: rowVersion,
  );
}

final class _Clock implements EconomyClock {
  const _Clock();

  @override
  DateTime nowUtc() => _now;
}

final class _Ids implements EconomyIdGenerator {
  int _next = 0;

  @override
  String nextId() => 'id-${_next++}';
}
