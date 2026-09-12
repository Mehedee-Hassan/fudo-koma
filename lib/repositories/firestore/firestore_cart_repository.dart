import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/food_cart_model.dart';
import '../../models/schedule_entry_model.dart';
import '../cart_repository.dart';
import 'firestore_refs.dart';

class FirestoreCartRepository implements CartRepository {
  FirestoreCartRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _carts =>
      FirestoreRefs.carts(_db);

  @override
  Stream<List<FoodCartModel>> watchCarts() =>
      _carts.orderBy('name').snapshots().map(
            (snap) => snap.docs
                .map((d) => FoodCartModel.fromMap(d.data(), d.id))
                .toList(),
          );

  @override
  Stream<FoodCartModel?> watchCart(String cartId) =>
      _carts.doc(cartId).snapshots().map(
            (doc) => doc.exists
                ? FoodCartModel.fromMap(doc.data()!, doc.id)
                : null,
          );

  @override
  Stream<FoodCartModel?> watchCartByOwner(String ownerId) => _carts
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .snapshots()
          .map((snap) {
        if (snap.docs.isEmpty) return null;
        final doc = snap.docs.first;
        return FoodCartModel.fromMap(doc.data(), doc.id);
      });

  @override
  Future<List<FoodCartModel>> fetchCarts() async {
    final snap = await _carts.get();
    return snap.docs
        .map((d) => FoodCartModel.fromMap(d.data(), d.id))
        .toList();
  }

  @override
  Future<FoodCartModel?> fetchCart(String cartId) async {
    final doc = await _carts.doc(cartId).get();
    return doc.exists ? FoodCartModel.fromMap(doc.data()!, doc.id) : null;
  }

  @override
  Future<FoodCartModel> createCart(FoodCartModel cart) async {
    final ref = cart.id.isEmpty ? _carts.doc() : _carts.doc(cart.id);
    final created = cart.copyWith(id: ref.id, updatedAt: DateTime.now());
    await ref.set(created.toMap());
    return created;
  }

  @override
  Future<void> updateCart(FoodCartModel cart) => _carts
      .doc(cart.id)
      .set(cart.copyWith(updatedAt: DateTime.now()).toMap());

  @override
  Future<void> setOpen({required String cartId, required bool isOpen}) =>
      _patch(cartId, {'isOpen': isOpen});

  @override
  Future<void> updateLocation({
    required String cartId,
    required double latitude,
    required double longitude,
    String? locationLabel,
  }) =>
      _patch(cartId, {
        'latitude': latitude,
        'longitude': longitude,
        'lastLocationAt': DateTime.now().toIso8601String(),
        if (locationLabel != null) 'locationLabel': locationLabel,
      });

  @override
  Future<void> replaceSchedule({
    required String cartId,
    required List<ScheduleEntry> entries,
  }) =>
      // Schedule entries are embedded rather than a subcollection: the set is
      // bounded (<= ~21) and always read with the cart, so one read beats two.
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
      // Atomic server-side increment: concurrent follows from two devices
      // cannot lose an update the way a read-modify-write would.
      _carts.doc(cartId).update(<String, dynamic>{
        'followersCount': FieldValue.increment(delta),
        'updatedAt': DateTime.now().toIso8601String(),
      });

  Future<void> _patch(String cartId, Map<String, dynamic> changes) =>
      _carts.doc(cartId).update(<String, dynamic>{
        ...changes,
        'updatedAt': DateTime.now().toIso8601String(),
      });
}
