import '../../core/id_generator.dart';
import '../../models/food_cart_model.dart';
import '../../models/schedule_entry_model.dart';
import '../cart_repository.dart';
import 'local_keys.dart';
import 'local_store.dart';

class LocalCartRepository implements CartRepository {
  LocalCartRepository(this._store);

  final LocalStore _store;

  List<FoodCartModel> _decode(Map<String, Map<String, dynamic>> docs) {
    final carts = docs.entries
        .map((e) => FoodCartModel.fromMap(e.value, e.key))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return carts;
  }

  @override
  Stream<List<FoodCartModel>> watchCarts() =>
      _store.watchCollection(LocalKeys.carts).map(_decode);

  @override
  Stream<FoodCartModel?> watchCart(String cartId) =>
      _store.watchCollection(LocalKeys.carts).map((docs) {
        final data = docs[cartId];
        return data == null ? null : FoodCartModel.fromMap(data, cartId);
      });

  @override
  Stream<FoodCartModel?> watchCartByOwner(String ownerId) =>
      _store.watchCollection(LocalKeys.carts).map((docs) {
        for (final entry in docs.entries) {
          if (entry.value['ownerId'] == ownerId) {
            return FoodCartModel.fromMap(entry.value, entry.key);
          }
        }
        return null;
      });

  @override
  Future<List<FoodCartModel>> fetchCarts() async =>
      _decode(_store.readCollection(LocalKeys.carts));

  @override
  Future<FoodCartModel?> fetchCart(String cartId) async {
    final data = _store.readDoc(LocalKeys.carts, cartId);
    return data == null ? null : FoodCartModel.fromMap(data, cartId);
  }

  @override
  Future<FoodCartModel> createCart(FoodCartModel cart) async {
    final id = cart.id.isEmpty ? newId('cart') : cart.id;
    final created = cart.copyWith(id: id, updatedAt: DateTime.now());
    await _store.setDoc(LocalKeys.carts, id, created.toMap());
    return created;
  }

  @override
  Future<void> updateCart(FoodCartModel cart) => _store.setDoc(
        LocalKeys.carts,
        cart.id,
        cart.copyWith(updatedAt: DateTime.now()).toMap(),
      );

  @override
  Future<void> setOpen({required String cartId, required bool isOpen}) =>
      _patch(cartId, {'isOpen': isOpen});

  @override
  Future<void> updateLocation({
    required String cartId,
    required double latitude,
    required double longitude,
    String? locationLabel,
  }) {
    final now = DateTime.now();
    return _patch(cartId, {
      'latitude': latitude,
      'longitude': longitude,
      'lastLocationAt': now.toIso8601String(),
      if (locationLabel != null) 'locationLabel': locationLabel,
    });
  }

  @override
  Future<void> replaceSchedule({
    required String cartId,
    required List<ScheduleEntry> entries,
  }) =>
      _patch(cartId, {
        'scheduleEntries': entries.map((e) => e.toMap()).toList(),
      });

  @override
  Future<void> setPhotos({
    required String cartId,
    required List<String> photoRefs,
  }) =>
      _patch(cartId, {'photoRefs': photoRefs});

  @override
  Future<void> setVisibility({
    required String cartId,
    required bool isActive,
  }) =>
      _patch(cartId, {'isActive': isActive});

  @override
  Future<void> adjustFollowerCount({
    required String cartId,
    required int delta,
  }) =>
      _store.updateDoc(LocalKeys.carts, cartId, (current) {
        final count = (current['followersCount'] as num?)?.toInt() ?? 0;
        // Clamped: a double-unfollow must not drive the count negative.
        current['followersCount'] = (count + delta).clamp(0, 1 << 31);
        current['updatedAt'] = DateTime.now().toIso8601String();
        return current;
      });

  Future<void> _patch(String cartId, Map<String, dynamic> changes) =>
      _store.updateDoc(LocalKeys.carts, cartId, (current) {
        current.addAll(changes);
        current['updatedAt'] = DateTime.now().toIso8601String();
        return current;
      });
}
