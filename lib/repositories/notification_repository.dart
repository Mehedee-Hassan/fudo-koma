import '../models/cart_update_model.dart';
import '../models/notification_model.dart';

abstract class NotificationRepository {
  Stream<List<NotificationModel>> watchFeed(String userId);
  Stream<int> watchUnreadCount(String userId);

  Future<void> push(NotificationModel notification);
  Future<void> pushAll(List<NotificationModel> notifications);
  Future<void> markRead(String notificationId);
  Future<void> markAllRead(String userId);

  /// The public half of the fan-out: a cart's own activity log.
  Future<void> recordCartUpdate(CartUpdateModel update);
  Stream<List<CartUpdateModel>> watchCartUpdates(String cartId);
}
