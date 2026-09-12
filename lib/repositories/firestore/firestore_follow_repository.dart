import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/follow_model.dart';
import '../cart_repository.dart';
import '../follow_repository.dart';
import 'firestore_refs.dart';

class FirestoreFollowRepository implements FollowRepository {
  FirestoreFollowRepository({
    required CartRepository carts,
    FirebaseFirestore? firestore,
  })  : _carts = carts,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final CartRepository _carts;

  CollectionReference<Map<String, dynamic>> get _follows =>
      FirestoreRefs.follows(_db);

  @override
  Stream<List<FollowModel>> watchFollows(String userId) => _follows
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => FollowModel.fromMap(d.data(), d.id))
          .toList()
        ..sort((a, b) => b.followedAt.compareTo(a.followedAt)));

  @override
  Future<List<FollowModel>> fetchFollows(String userId) async {
    final snap = await _follows.where('userId', isEqualTo: userId).get();
    return snap.docs.map((d) => FollowModel.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<FollowModel> follow({
    required String userId,
    required String cartId,
    bool notificationsEnabled = true,
    int? proximityAlertKm,
  }) async {
    final id = FollowModel.idFor(userId, cartId);
    final ref = _follows.doc(id);
    final existing = await ref.get();

    final follow = FollowModel(
      id: id,
      userId: userId,
      cartId: cartId,
      followedAt: existing.exists
          ? FollowModel.fromMap(existing.data()!, id).followedAt
          : DateTime.now(),
      notificationsEnabled: notificationsEnabled,
      proximityAlertKm: proximityAlertKm ?? FollowRepository.defaultRadiusKm,
    );

    await ref.set(follow.toMap());
    if (!existing.exists) {
      await _carts.adjustFollowerCount(cartId: cartId, delta: 1);
    }
    return follow;
  }

  @override
  Future<void> unfollow({
    required String userId,
    required String cartId,
  }) async {
    final ref = _follows.doc(FollowModel.idFor(userId, cartId));
    if (!(await ref.get()).exists) return;
    await ref.delete();
    await _carts.adjustFollowerCount(cartId: cartId, delta: -1);
  }

  @override
  Future<void> updateFollow(FollowModel follow) =>
      _follows.doc(follow.id).set(follow.toMap());

  @override
  Future<List<String>> followerIdsForCart(String cartId) async {
    final snap = await _follows.where('cartId', isEqualTo: cartId).get();
    return snap.docs
        .map((d) => d.data()['userId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }
}
