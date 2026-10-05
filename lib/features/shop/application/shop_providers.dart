import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/persistence_providers.dart';
import '../../../core/result/result.dart';
import '../../economy/application/economy_providers.dart';
import '../domain/models/wish.dart';
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

T _unwrap<T>(Result<T> result) => result.fold(
  onSuccess: (T value) => value,
  onFailure: (failure) => throw failure,
);
