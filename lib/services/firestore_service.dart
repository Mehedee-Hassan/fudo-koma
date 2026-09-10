import '../models/follow_model.dart';
import '../models/food_cart_model.dart';
import '../models/notification_model.dart';
import '../models/user_profile_model.dart';

class FirestoreService {
  Future<List<FoodCartModel>> fetchFoodCarts() async {
    return FoodCartModel.demoCarts();
  }

  Future<List<UserProfileModel>> fetchModerationQueue() async {
    return [
      UserProfileModel(
        id: 'user-99',
        name: 'Samir A.',
        role: 'customer',
        isGuest: false,
        isBlocked: false,
        createdAt: DateTime.now().subtract(const Duration(days: 6)),
      ),
      UserProfileModel(
        id: 'user-101',
        name: 'Maya C.',
        role: 'customer',
        isGuest: false,
        isBlocked: true,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
    ];
  }

  Future<void> updateCartStatus({
    required String cartId,
    required bool isOpen,
    required String schedule,
  }) async {
    // Replace this with Firestore write when backend is connected.
    return;
  }

  Future<void> followCart({
    required String userId,
    required String cartId,
    required bool notificationsEnabled,
  }) async {
    // Replace this with Firestore follow document creation.
    return;
  }

  Future<void> blockUser({required String userId}) async {
    // Replace this with admin moderation write.
    return;
  }

  Future<List<NotificationModel>> fetchNotifications(String userId) async {
    return [
      NotificationModel(
        id: 'note-1',
        userId: userId,
        cartId: 'cart-1',
        type: 'nearby',
        message: 'Momo House is within 3 km of your location.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
      ),
      NotificationModel(
        id: 'note-2',
        userId: userId,
        cartId: 'cart-2',
        type: 'schedule',
        message: 'The Green Bowl changed its schedule.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];
  }

  Future<List<FollowModel>> fetchFollows(String userId) async {
    return [
      FollowModel(
        id: 'follow-1',
        userId: userId,
        cartId: 'cart-1',
        followedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      FollowModel(
        id: 'follow-2',
        userId: userId,
        cartId: 'cart-3',
        followedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];
  }
}
