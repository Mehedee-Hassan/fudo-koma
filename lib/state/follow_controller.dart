import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/follow_model.dart';
import '../repositories/follow_repository.dart';

class FollowController extends ChangeNotifier {
  FollowController(this._repository);

  final FollowRepository _repository;
  StreamSubscription<List<FollowModel>>? _sub;

  String? _userId;
  List<FollowModel> _follows = const <FollowModel>[];

  List<FollowModel> get follows => _follows;
  Set<String> get followedCartIds =>
      _follows.map((f) => f.cartId).toSet();

  bool isFollowing(String cartId) =>
      _follows.any((f) => f.cartId == cartId);

  FollowModel? followFor(String cartId) {
    for (final follow in _follows) {
      if (follow.cartId == cartId) return follow;
    }
    return null;
  }

  /// Idempotent: re-binding the same id is a no-op, so a proxy provider can
  /// call this on every rebuild without tearing down a live subscription.
  void bindUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _sub?.cancel();
    _sub = null;

    if (userId == null) {
      _follows = const <FollowModel>[];
      notifyListeners();
      return;
    }

    _sub = _repository.watchFollows(userId).listen((follows) {
      _follows = follows;
      notifyListeners();
    });
  }

  Future<void> toggle(String cartId) async {
    final userId = _userId;
    if (userId == null) return;

    if (isFollowing(cartId)) {
      await _repository.unfollow(userId: userId, cartId: cartId);
    } else {
      await _repository.follow(userId: userId, cartId: cartId);
    }
  }

  Future<void> setNotificationsEnabled(String cartId, bool enabled) async {
    final follow = followFor(cartId);
    if (follow == null) return;
    await _repository
        .updateFollow(follow.copyWith(notificationsEnabled: enabled));
  }

  Future<void> setProximityKm(String cartId, int km) async {
    final follow = followFor(cartId);
    if (follow == null) return;
    await _repository.updateFollow(follow.copyWith(proximityAlertKm: km));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
