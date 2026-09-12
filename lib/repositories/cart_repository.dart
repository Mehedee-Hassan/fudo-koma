import '../models/food_cart_model.dart';
import '../models/schedule_entry_model.dart';

/// Reads are streams, writes are futures.
///
/// Firestore is natively stream-shaped and local mode has to push changes to
/// the UI anyway, so a stream read path removes every manual "reload after
/// write" call site - a whole class of stale-UI bugs.
abstract class CartRepository {
  Stream<List<FoodCartModel>> watchCarts();
  Stream<FoodCartModel?> watchCart(String cartId);
  Stream<FoodCartModel?> watchCartByOwner(String ownerId);

  /// One-shot read for proximity sweeps and tests.
  Future<List<FoodCartModel>> fetchCarts();
  Future<FoodCartModel?> fetchCart(String cartId);

  Future<FoodCartModel> createCart(FoodCartModel cart);
  Future<void> updateCart(FoodCartModel cart);
  Future<void> setOpen({required String cartId, required bool isOpen});

  Future<void> updateLocation({
    required String cartId,
    required double latitude,
    required double longitude,
    String? locationLabel,
  });

  Future<void> replaceSchedule({
    required String cartId,
    required List<ScheduleEntry> entries,
  });

  Future<void> setPhotos({
    required String cartId,
    required List<String> photoRefs,
  });

  /// Admin takedown, and the cascade when a cart's owner is blocked.
  Future<void> setVisibility({required String cartId, required bool isActive});

  Future<void> adjustFollowerCount({
    required String cartId,
    required int delta,
  });
}
