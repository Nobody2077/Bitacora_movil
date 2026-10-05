import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/persistence_providers.dart';
import '../../../core/result/result.dart';
import '../../economy/application/economy_providers.dart';
import '../domain/models/wish.dart';
import '../domain/models/wish_affordability.dart';
import 'shop_application_service.dart';

final Provider<ShopApplicationService> shopApplicationServiceProvider =
    Provider<ShopApplicationService>(
      (Ref ref) => ShopApplicationService(
        repository: ref.watch(wishRepositoryProvider),
        clock: ref.watch(economyClockProvider),
        idGenerator: ref.watch(economyIdGeneratorProvider),
      ),
    );

final StreamProvider<List<Wish>> activeWishesProvider =
    StreamProvider<List<Wish>>(
      (Ref ref) => ref
          .watch(wishRepositoryProvider)
          .watchActive()
          .map(_unwrap<List<Wish>>),
    );

final StreamProvider<List<Wish>> archivedWishesProvider =
    StreamProvider<List<Wish>>(
      (Ref ref) => ref
          .watch(wishRepositoryProvider)
          .watchArchived()
          .map(_unwrap<List<Wish>>),
    );

final StreamProvider<List<Wish>> purchasedWishesProvider =
    StreamProvider<List<Wish>>(
      (Ref ref) => ref
          .watch(wishRepositoryProvider)
          .watchPurchased()
          .map(_unwrap<List<Wish>>),
    );

final wishProvider = StreamProvider.family<Wish?, String>(
  (Ref ref, String id) =>
      ref.watch(wishRepositoryProvider).watchById(id).map(_unwrap<Wish?>),
);

/// Para cada deseo activo **con precio**, su nombre y si el saldo disponible
/// ya lo alcanza. Nulo mientras falte la lista o el saldo.
final Provider<Map<String, ({String name, bool affordable})>?>
wishAffordabilityProvider =
    Provider<Map<String, ({String name, bool affordable})>?>((Ref ref) {
      final List<Wish>? wishes = ref.watch(activeWishesProvider).value;
      final int? available = ref
          .watch(economySnapshotProvider)
          .value
          ?.availableMinor;
      if (wishes == null || available == null) return null;
      return <String, ({String name, bool affordable})>{
        for (final Wish wish in wishes)
          if (wish.priceMinor != null)
            wish.id: (
              name: wish.name,
              affordable: WishAffordability.evaluate(
                priceMinor: wish.priceMinor,
                availableMinor: available,
              ).isAffordable,
            ),
      };
    });

/// Una compra recién hecha, para que la cabecera del menú anime el saldo
/// bajando en naranja (ADR-006 D12) cuando vuelva a verse.
final class PurchaseFeedback {
  const PurchaseFeedback({
    required this.amountMinor,
    required this.balanceBeforeMinor,
  });

  final int amountMinor;

  /// Saldo disponible justo antes de comprar: el punto de partida de la
  /// animación, aunque Economía aún no haya emitido el saldo nuevo.
  final int balanceBeforeMinor;
}

final NotifierProvider<PurchaseFeedbackController, PurchaseFeedback?>
purchaseFeedbackProvider =
    NotifierProvider<PurchaseFeedbackController, PurchaseFeedback?>(
      PurchaseFeedbackController.new,
    );

class PurchaseFeedbackController extends Notifier<PurchaseFeedback?> {
  @override
  PurchaseFeedback? build() => null;

  void announce(PurchaseFeedback feedback) => state = feedback;

  /// Entrega la compra pendiente una sola vez.
  PurchaseFeedback? take() {
    final PurchaseFeedback? pending = state;
    state = null;
    return pending;
  }
}

T _unwrap<T>(Result<T> result) => result.fold(
  onSuccess: (T value) => value,
  onFailure: (failure) => throw failure,
);
