import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/persistence_providers.dart';
import '../application/shop_providers.dart';

typedef _AffordabilityMap = Map<String, ({String name, bool affordable})>;

/// Vuelve a calcular el resumen diario (con su «N deseos a tu alcance»).
final Provider<Future<void> Function()> dailySummaryRefresherProvider =
    Provider<Future<void> Function()>(
      (Ref ref) => () async {
        await ref.read(notificationReconciliationServiceProvider).reconcile();
      },
    );

/// Avisa dentro de la app cuando un deseo **pasa** a estar al alcance del
/// saldo (ADR-006 D17), y refresca el resumen diario cuando cambia cuántos
/// alcanzas. Vive alrededor del shell protegido: solo con la app desbloqueada.
class WishAffordabilityWatcher extends ConsumerWidget {
  const WishAffordabilityWatcher({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<_AffordabilityMap?>(wishAffordabilityProvider, (
      _AffordabilityMap? previous,
      _AffordabilityMap? next,
    ) {
      // La primera lectura solo fija el punto de partida: no se avisa de lo
      // que ya estaba al alcance al abrir la app.
      if (previous == null || next == null) return;

      final List<String> reached = <String>[
        for (final MapEntry<String, ({String name, bool affordable})> entry
            in next.entries)
          if (entry.value.affordable &&
              previous[entry.key]?.affordable == false)
            entry.value.name,
      ];
      if (reached.isNotEmpty) {
        _announce(context, reached);
      }
      if (_affordableIds(previous).length != _affordableIds(next).length ||
          !_affordableIds(previous).containsAll(_affordableIds(next))) {
        unawaited(_refreshDailySummary(ref));
      }
    });
    return child;
  }

  static Set<String> _affordableIds(_AffordabilityMap map) => <String>{
    for (final MapEntry<String, ({String name, bool affordable})> entry
        in map.entries)
      if (entry.value.affordable) entry.key,
  };

  static void _announce(BuildContext context, List<String> names) {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        key: const Key('wish-reached-notice'),
        content: Text(
          names.length == 1
              ? 'Ya puedes comprar: ${names.single}'
              : 'Ya puedes comprar ${names.length} deseos',
        ),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () => GoRouter.maybeOf(context)?.goNamed(
            'character',
            queryParameters: const <String, String>{'tab': 'tienda'},
          ),
        ),
      ),
    );
  }

  static Future<void> _refreshDailySummary(WidgetRef ref) async {
    try {
      await ref.read(dailySummaryRefresherProvider)();
    } on Object {
      // El aviso de la Tienda no debe romper nada si el resumen no se
      // pudo reprogramar; se recalcula en la siguiente pasada.
    }
  }
}
