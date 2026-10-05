import 'dart:async';

import 'package:bitacora_rpg_personal/app/theme/app_theme.dart';
import 'package:bitacora_rpg_personal/features/economy/application/economy_providers.dart';
import 'package:bitacora_rpg_personal/features/economy/domain/models/economy_snapshot.dart';
import 'package:bitacora_rpg_personal/features/shop/application/shop_providers.dart';
import 'package:bitacora_rpg_personal/features/shop/domain/models/wish.dart';
import 'package:bitacora_rpg_personal/features/shop/presentation/wish_affordability_watcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _now = DateTime.utc(2026, 10, 5, 12);

void main() {
  late StreamController<List<Wish>> wishes;
  late StreamController<EconomySnapshot> balance;
  late int refreshes;

  setUp(() {
    wishes = StreamController<List<Wish>>();
    balance = StreamController<EconomySnapshot>();
    refreshes = 0;
  });

  tearDown(() async {
    await wishes.close();
    await balance.close();
  });

  Future<void> pumpWatcher(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeWishesProvider.overrideWith((Ref ref) => wishes.stream),
          economySnapshotProvider.overrideWith((Ref ref) => balance.stream),
          dailySummaryRefresherProvider.overrideWithValue(() async {
            refreshes++;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const WishAffordabilityWatcher(
            child: Scaffold(body: Text('shell')),
          ),
        ),
      ),
    );
  }

  Future<void> emit(
    WidgetTester tester, {
    List<Wish>? list,
    int? available,
  }) async {
    if (list != null) wishes.add(list);
    if (available != null) balance.add(_snapshot(available));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('no avisa al abrir de lo que ya alcanzabas', (
    WidgetTester tester,
  ) async {
    await pumpWatcher(tester);
    await emit(
      tester,
      list: <Wish>[_wish('a', 'Audífonos', 30000)],
      available: 50000,
    );

    expect(find.byKey(const Key('wish-reached-notice')), findsNothing);
    expect(refreshes, 0);
  });

  testWidgets('avisa cuando un ingreso deja un deseo al alcance', (
    WidgetTester tester,
  ) async {
    await pumpWatcher(tester);
    await emit(
      tester,
      list: <Wish>[
        _wish('m', 'Monitor 27"', 120000),
        _wish('b', 'Bicicleta', 900000),
      ],
      available: 100000,
    );

    await emit(tester, available: 130000);

    expect(find.text('Ya puedes comprar: Monitor 27"'), findsOneWidget);
    expect(find.text('Ver'), findsOneWidget);
    expect(refreshes, 1);
  });

  testWidgets('con varios a la vez dice cuántos', (WidgetTester tester) async {
    await pumpWatcher(tester);
    await emit(
      tester,
      list: <Wish>[
        _wish('m', 'Monitor', 120000),
        _wish('t', 'Teclado', 110000),
      ],
      available: 100000,
    );

    await emit(tester, available: 150000);

    expect(find.text('Ya puedes comprar 2 deseos'), findsOneWidget);
  });

  testWidgets('no repite el aviso mientras siga al alcance', (
    WidgetTester tester,
  ) async {
    await pumpWatcher(tester);
    await emit(
      tester,
      list: <Wish>[_wish('m', 'Monitor', 120000)],
      available: 100000,
    );
    await emit(tester, available: 130000);
    ScaffoldMessenger.of(
      tester.element(find.text('shell')),
    ).removeCurrentSnackBar();
    await tester.pumpAndSettle();

    await emit(tester, available: 140000);

    expect(find.byKey(const Key('wish-reached-notice')), findsNothing);
    expect(refreshes, 1);
  });

  testWidgets('un deseo nuevo que ya alcanzas no avisa, pero cuenta', (
    WidgetTester tester,
  ) async {
    await pumpWatcher(tester);
    await emit(
      tester,
      list: <Wish>[_wish('m', 'Monitor', 120000)],
      available: 100000,
    );

    await emit(
      tester,
      list: <Wish>[_wish('m', 'Monitor', 120000), _wish('l', 'Libro', 5000)],
    );

    expect(find.byKey(const Key('wish-reached-notice')), findsNothing);
    expect(refreshes, 1);
  });

  testWidgets('dejar de alcanzarlo no avisa y refresca el resumen', (
    WidgetTester tester,
  ) async {
    await pumpWatcher(tester);
    await emit(
      tester,
      list: <Wish>[_wish('m', 'Monitor', 120000)],
      available: 130000,
    );

    await emit(tester, available: 90000);

    expect(find.byKey(const Key('wish-reached-notice')), findsNothing);
    expect(refreshes, 1);
  });
}

EconomySnapshot _snapshot(int availableMinor) => EconomySnapshot(
  totalMinor: availableMinor,
  reservedMinor: 0,
  monthIncomeMinor: 0,
  monthExpenseMinor: 0,
  dayIncomeMinor: 0,
  dayExpenseMinor: 0,
);

Wish _wish(String id, String name, int price) => Wish(
  id: id,
  name: name,
  kind: WishKind.other,
  priority: WishPriority.medium,
  priceMinor: price,
  createdAtUtc: _now,
  updatedAtUtc: _now,
  rowVersion: 1,
);
