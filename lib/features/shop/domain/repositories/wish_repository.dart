import '../../../../core/result/result.dart';
import '../../../economy/domain/models/economy_models.dart';
import '../models/wish.dart';

abstract interface class WishRepository {
  Stream<Result<List<Wish>>> watchActive();

  Stream<Result<List<Wish>>> watchArchived();

  Stream<Result<List<Wish>>> watchPurchased();

  Stream<Result<Wish?>> watchById(String id);

  Future<Result<Wish>> create(Wish wish);

  /// Guarda los datos si [Wish.rowVersion] sigue vigente.
  Future<Result<Wish>> update(Wish wish);

  Future<Result<Wish>> archive(Wish wish, {required DateTime atUtc});

  Future<Result<Wish>> restore(Wish wish, {required DateTime atUtc});

  /// Escribe [expense] y marca [wish] como comprado, todo o nada.
  Future<Result<Wish>> purchase(
    Wish wish, {
    required EconomyTransaction expense,
  });
}
