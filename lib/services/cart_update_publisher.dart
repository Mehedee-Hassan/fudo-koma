import '../core/id_generator.dart';
import '../models/cart_update_model.dart';
import '../models/food_cart_model.dart';
import '../models/notification_model.dart';
import '../repositories/follow_repository.dart';
import '../repositories/notification_repository.dart';

/// Fan-out on write.
///
/// One owner action produces one public `CartUpdateModel` on the cart's log
/// plus one `NotificationModel` per follower inbox. The Updates tab then reads
/// a single stream with no client-side join - exactly what a Cloud Function
/// would do server-side, so the local implementation rehearses the real shape.
///
/// Write amplification is irrelevant at this scale.
class CartUpdatePublisher {
  const CartUpdatePublisher({
    required FollowRepository follows,
    required NotificationRepository notifications,
  })  : _follows = follows,
        _notifications = notifications;

  final FollowRepository _follows;
  final NotificationRepository _notifications;

  Future<void> publish({
    required FoodCartModel cart,
    required CartUpdateType type,
    required String message,
    String? locationLabel,
    double? latitude,
    double? longitude,
  }) async {
    final now = DateTime.now();

    await _notifications.recordCartUpdate(CartUpdateModel(
      id: newId('update'),
      cartId: cart.id,
      cartName: cart.name,
      ownerId: cart.ownerId,
      type: type,
      message: message,
      locationLabel: locationLabel,
      latitude: latitude,
      longitude: longitude,
      createdAt: now,
    ));

    final followerIds = await _follows.followerIdsForCart(cart.id);
    if (followerIds.isEmpty) return;

    await _notifications.pushAll(<NotificationModel>[
      for (final followerId in followerIds)
        // The owner does not need a notification about their own action.
        if (followerId != cart.ownerId)
          NotificationModel(
            id: newId('note'),
            userId: followerId,
            cartId: cart.id,
            cartName: cart.name,
            type: _notificationType(type),
            message: message,
            createdAt: now,
          ),
    ]);
  }

  static NotificationType _notificationType(CartUpdateType type) =>
      switch (type) {
        CartUpdateType.opened => NotificationType.opened,
        CartUpdateType.closed => NotificationType.closed,
        CartUpdateType.moved => NotificationType.moved,
        CartUpdateType.scheduleChanged => NotificationType.scheduleChanged,
        CartUpdateType.photoAdded => NotificationType.announcement,
        CartUpdateType.announcement => NotificationType.announcement,
      };
}
