import '../../models/follow_model.dart';
import '../cart_repository.dart';
import '../follow_repository.dart';
import 'local_keys.dart';
import 'local_store.dart';

class LocalFollowRepository implements FollowRepository {
  LocalFollowRepository(this._store, this._carts);

  final LocalStore _store;
  final CartRepository _carts;

  List<FollowModel> _decodeFor(
    Map<String, Map<String, dynamic>> docs,
    String userId,
  ) {
    final follows = docs.entries
        .where((e) => e.value['userId'] == userId)
        .map((e) => FollowModel.fromMap(e.value, e.key))
        .toList()
      ..sort((a, b) => b.followedAt.compareTo(a.followedAt));
    return follows;
  }

  @override
  Stream<List<FollowModel>> watchFollows(String userId) =>
      _store.watchCollection(LocalKeys.follows).map((d) => _decodeFor(d, userId));

  @override
  Future<List<FollowModel>> fetchFollows(String userId) async =>
      _decodeFor(_store.readCollection(LocalKeys.follows), userId);

  @override
  Future<FollowModel> follow({
    required String userId,
    required String cartId,
    bool notificationsEnabled = true,
    int? proximityAlertKm,
  }) async {
    final id = FollowModel.idFor(userId, cartId);
    final existing = _store.readDoc(LocalKeys.follows, id);

    final follow = FollowModel(
      id: id,
      userId: userId,
      cartId: cartId,
      followedAt: existing == null
          ? DateTime.now()
          : DateTime.tryParse(existing['followedAt'] as String? ?? '') ??
              DateTime.now(),
      notificationsEnabled: notificationsEnabled,
      proximityAlertKm: proximityAlertKm ?? FollowRepository.defaultRadiusKm,
    );

    await _store.setDoc(LocalKeys.follows, id, follow.toMap());
    // Idempotent: a repeat follow must not inflate the counter.
    if (existing == null) {
      await _carts.adjustFollowerCount(cartId: cartId, delta: 1);
    }
    return follow;
  }

  @override
  Future<void> unfollow({
    required String userId,
    required String cartId,
  }) async {
    final id = FollowModel.idFor(userId, cartId);
    if (_store.readDoc(LocalKeys.follows, id) == null) return;
    await _store.deleteDoc(LocalKeys.follows, id);
    await _carts.adjustFollowerCount(cartId: cartId, delta: -1);
  }

  @override
  Future<void> updateFollow(FollowModel follow) =>
      _store.setDoc(LocalKeys.follows, follow.id, follow.toMap());

  @override
  Future<List<String>> followerIdsForCart(String cartId) async {
    return _store
        .readCollection(LocalKeys.follows)
        .values
        .where((doc) => doc['cartId'] == cartId)
        .map((doc) => doc['userId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }
}
