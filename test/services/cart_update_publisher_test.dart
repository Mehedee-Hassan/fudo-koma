import 'package:flutter_test/flutter_test.dart';
import 'package:follo_cart/models/cart_update_model.dart';
import 'package:follo_cart/models/food_cart_model.dart';
import 'package:follo_cart/models/notification_model.dart';
import 'package:follo_cart/services/cart_update_publisher.dart';

import '../support/fakes.dart';

void main() {
  late FakeCartRepository carts;
  late FakeFollowRepository follows;
  late FakeNotificationRepository notifications;
  late CartUpdatePublisher publisher;

  final cart = testCart(id: 'cart-1', name: 'Momo House', ownerId: 'owner-1');

  setUp(() {
    carts = FakeCartRepository(<FoodCartModel>[cart]);
    follows = FakeFollowRepository(carts);
    notifications = FakeNotificationRepository();
    publisher = CartUpdatePublisher(
      follows: follows,
      notifications: notifications,
    );
  });

  test('writes one public update and one inbox item per follower', () async {
    await follows.follow(userId: 'u1', cartId: 'cart-1');
    await follows.follow(userId: 'u2', cartId: 'cart-1');

    await publisher.publish(
      cart: cart,
      type: CartUpdateType.opened,
      message: 'Momo House is open now.',
    );

    expect(notifications.updates, hasLength(1));
    expect(notifications.updates.single.type, CartUpdateType.opened);

    expect(notifications.feedFor('u1'), hasLength(1));
    expect(notifications.feedFor('u2'), hasLength(1));
    expect(notifications.feedFor('u1').single.type, NotificationType.opened);
  });

  test('a non-follower receives nothing', () async {
    await follows.follow(userId: 'u1', cartId: 'cart-1');

    await publisher.publish(
      cart: cart,
      type: CartUpdateType.closed,
      message: 'Momo House has closed.',
    );

    expect(notifications.feedFor('u1'), hasLength(1));
    expect(notifications.feedFor('stranger'), isEmpty);
  });

  test('the owner is not notified about their own action', () async {
    await follows.follow(userId: 'owner-1', cartId: 'cart-1');

    await publisher.publish(
      cart: cart,
      type: CartUpdateType.moved,
      message: 'Momo House is on the move.',
    );

    // The public log still records it; only the owner's inbox is spared.
    expect(notifications.updates, hasLength(1));
    expect(notifications.feedFor('owner-1'), isEmpty);
  });

  test('still records the public update with no followers', () async {
    await publisher.publish(
      cart: cart,
      type: CartUpdateType.announcement,
      message: 'Fresh batch at 6pm.',
    );

    expect(notifications.updates, hasLength(1));
    expect(await notifications.watchCartUpdates('cart-1').first, hasLength(1));
  });

  test('maps every update type to a notification type', () async {
    await follows.follow(userId: 'u1', cartId: 'cart-1');

    for (final type in CartUpdateType.values) {
      await publisher.publish(cart: cart, type: type, message: 'x');
    }

    expect(
      notifications.feedFor('u1'),
      hasLength(CartUpdateType.values.length),
    );
    expect(
      notifications.feedFor('u1').every(
            (n) => n.type != NotificationType.system,
          ),
      isTrue,
    );
  });
}
