import '../core/app_constants.dart';
import '../models/follow_model.dart';

abstract class FollowRepository {
  Stream<List<FollowModel>> watchFollows(String userId);
  Future<List<FollowModel>> fetchFollows(String userId);

  Future<FollowModel> follow({
    required String userId,
    required String cartId,
    bool notificationsEnabled = true,
    int? proximityAlertKm,
  });

  Future<void> unfollow({required String userId, required String cartId});
  Future<void> updateFollow(FollowModel follow);

  /// Drives the fan-out when an owner publishes an update.
  Future<List<String>> followerIdsForCart(String cartId);

  static int get defaultRadiusKm => AppConstants.alertRadiusKm.round();
}
