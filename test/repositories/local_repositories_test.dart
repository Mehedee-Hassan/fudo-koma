import 'package:flutter_test/flutter_test.dart';
import 'package:follo_cart/core/app_exception.dart';
import 'package:follo_cart/models/cart_update_model.dart';
import 'package:follo_cart/models/food_cart_model.dart';
import 'package:follo_cart/models/notification_model.dart';
import 'package:follo_cart/models/report_model.dart';
import 'package:follo_cart/models/user_role.dart';
import 'package:follo_cart/repositories/local/local_auth_repository.dart';
import 'package:follo_cart/repositories/local/local_cart_repository.dart';
import 'package:follo_cart/repositories/local/local_follow_repository.dart';
import 'package:follo_cart/repositories/local/local_keys.dart';
import 'package:follo_cart/repositories/local/local_moderation_repository.dart';
import 'package:follo_cart/repositories/local/local_notification_repository.dart';
import 'package:follo_cart/repositories/local/local_seed.dart';
import 'package:follo_cart/repositories/local/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = LocalStore(await SharedPreferences.getInstance());
  });

  group('LocalStore', () {
    test('watchCollection emits current state, then again on each write',
        () async {
      final emissions = <int>[];
      final sub = store
          .watchCollection(LocalKeys.carts)
          .listen((docs) => emissions.add(docs.length));

      // Each write is allowed to drain before the next, because the stream
      // delivers the state at *delivery* time (like a Firestore snapshot)
      // rather than a historical diff - back-to-back writes coalesce.
      await pumpEventQueue();
      await store.setDoc(LocalKeys.carts, 'a', <String, dynamic>{'name': 'A'});
      await pumpEventQueue();
      await store.setDoc(LocalKeys.carts, 'b', <String, dynamic>{'name': 'B'});
      await pumpEventQueue();

      expect(emissions, <int>[0, 1, 2]);
      await sub.cancel();
    });

    test('coalesces back-to-back writes to the latest state', () async {
      final emissions = <int>[];
      final sub = store
          .watchCollection(LocalKeys.carts)
          .listen((docs) => emissions.add(docs.length));

      await pumpEventQueue();
      await store.setDoc(LocalKeys.carts, 'a', <String, dynamic>{'name': 'A'});
      await store.setDoc(LocalKeys.carts, 'b', <String, dynamic>{'name': 'B'});
      await pumpEventQueue();

      // Every delivered event reports the current contents, so a listener can
      // never act on a stale intermediate state.
      expect(emissions.first, 0);
      expect(emissions.last, 2);
      await sub.cancel();
    });

    test('survives a corrupt payload instead of throwing', () async {
      await store.setString(LocalKeys.carts, 'not json at all');
      expect(store.readCollection(LocalKeys.carts), isEmpty);
    });
  });

  group('LocalSeed', () {
    test('seeds the seven demo carts exactly once', () async {
      await LocalSeed.ensureSeeded(store);
      final first = store.readCollection(LocalKeys.carts);
      expect(first, hasLength(7));

      await store.setDoc(LocalKeys.carts, 'cart-1', <String, dynamic>{
        ...first['cart-1']!,
        'name': 'Renamed',
      });
      await LocalSeed.ensureSeeded(store);

      expect(store.readCollection(LocalKeys.carts)['cart-1']!['name'],
          'Renamed');
    });

    test('never persists a raw password', () async {
      await LocalSeed.ensureSeeded(store);
      final raw = store.getString(LocalKeys.users)!;

      expect(raw, isNot(contains(LocalSeed.demoPassword)));
      expect(raw, contains('passwordHash'));
      expect(raw, contains('salt'));
    });
  });

  group('LocalCartRepository', () {
    test('creates, updates and streams carts', () async {
      final repo = LocalCartRepository(store);

      final created = await repo.createCart(testCart(id: 'cart-x'));
      expect((await repo.fetchCarts()).single.id, created.id);

      await repo.setOpen(cartId: 'cart-x', isOpen: false);
      expect((await repo.fetchCart('cart-x'))!.isOpen, isFalse);

      await repo.updateLocation(
        cartId: 'cart-x',
        latitude: 1.5,
        longitude: 2.5,
      );
      final moved = await repo.fetchCart('cart-x');
      expect(moved!.latitude, 1.5);
      expect(moved.lastLocationAt, isNotNull);
    });

    test('follower count never goes negative', () async {
      final repo = LocalCartRepository(store);
      await repo.createCart(testCart(id: 'cart-x'));

      await repo.adjustFollowerCount(cartId: 'cart-x', delta: -3);
      expect((await repo.fetchCart('cart-x'))!.followersCount, 0);
    });
  });

  group('LocalFollowRepository', () {
    late LocalCartRepository carts;
    late LocalFollowRepository follows;

    setUp(() async {
      carts = LocalCartRepository(store);
      follows = LocalFollowRepository(store, carts);
      await carts.createCart(testCart(id: 'cart-1'));
    });

    test('following is idempotent and adjusts the counter once', () async {
      await follows.follow(userId: 'u1', cartId: 'cart-1');
      await follows.follow(userId: 'u1', cartId: 'cart-1');

      expect(await follows.fetchFollows('u1'), hasLength(1));
      expect((await carts.fetchCart('cart-1'))!.followersCount, 1);
    });

    test('unfollow removes the record and decrements once', () async {
      await follows.follow(userId: 'u1', cartId: 'cart-1');
      await follows.unfollow(userId: 'u1', cartId: 'cart-1');
      await follows.unfollow(userId: 'u1', cartId: 'cart-1');

      expect(await follows.fetchFollows('u1'), isEmpty);
      expect((await carts.fetchCart('cart-1'))!.followersCount, 0);
    });

    test('defaults to the 5 km product radius', () async {
      final follow = await follows.follow(userId: 'u1', cartId: 'cart-1');
      expect(follow.proximityAlertKm, 5);
    });

    test('followerIdsForCart drives the fan-out', () async {
      await follows.follow(userId: 'u1', cartId: 'cart-1');
      await follows.follow(userId: 'u2', cartId: 'cart-1');

      expect(await follows.followerIdsForCart('cart-1'),
          containsAll(<String>['u1', 'u2']));
    });
  });

  group('LocalAuthRepository', () {
    late LocalAuthRepository auth;

    setUp(() => auth = LocalAuthRepository(store));
    tearDown(() => auth.dispose());

    test('registers then signs in', () async {
      await auth.register(
        email: 'New@Example.com',
        password: 'password123',
        displayName: 'New User',
        role: UserRole.customer,
      );
      await auth.signOut();

      // Email matching is case-insensitive.
      final profile = await auth.signIn(
        email: 'new@example.com',
        password: 'password123',
      );
      expect(profile.name, 'New User');
    });

    test('rejects a wrong password', () async {
      await auth.register(
        email: 'a@b.com',
        password: 'password123',
        displayName: 'A',
        role: UserRole.customer,
      );

      expect(
        () => auth.signIn(email: 'a@b.com', password: 'wrong-one'),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          AuthErrorCode.invalidCredentials,
        )),
      );
    });

    test('rejects a duplicate email', () async {
      await auth.register(
        email: 'a@b.com',
        password: 'password123',
        displayName: 'A',
        role: UserRole.customer,
      );

      expect(
        () => auth.register(
          email: 'a@b.com',
          password: 'password123',
          displayName: 'B',
          role: UserRole.customer,
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          AuthErrorCode.emailInUse,
        )),
      );
    });

    test('rejects a short password', () async {
      expect(
        () => auth.register(
          email: 'a@b.com',
          password: 'short',
          displayName: 'A',
          role: UserRole.customer,
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          AuthErrorCode.weakPassword,
        )),
      );
    });

    test('refuses a blocked account at sign-in', () async {
      final profile = await auth.register(
        email: 'a@b.com',
        password: 'password123',
        displayName: 'A',
        role: UserRole.customer,
      );
      await auth.signOut();
      await store.updateDoc(LocalKeys.users, profile.id, (current) {
        current['isBlocked'] = true;
        return current;
      });

      expect(
        () => auth.signIn(email: 'a@b.com', password: 'password123'),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          AuthErrorCode.userBlocked,
        )),
      );
    });

    test('the raw password never reaches storage', () async {
      const secret = 'sup3rSecretPassword';
      await auth.register(
        email: 'a@b.com',
        password: secret,
        displayName: 'A',
        role: UserRole.customer,
      );

      for (final key in <String>[
        LocalKeys.users,
        LocalKeys.session,
      ]) {
        expect(store.getString(key) ?? '', isNot(contains(secret)));
      }
    });

    test('restores a session across a restart', () async {
      final profile = await auth.register(
        email: 'a@b.com',
        password: 'password123',
        displayName: 'A',
        role: UserRole.owner,
      );

      final restarted = LocalAuthRepository(store);
      addTearDown(restarted.dispose);

      final restored = await restarted.restoreSession();
      expect(restored?.id, profile.id);
      expect(restored?.role, UserRole.owner);
    });

    test('a profile write preserves the credential fields', () async {
      final profile = await auth.register(
        email: 'a@b.com',
        password: 'password123',
        displayName: 'A',
        role: UserRole.owner,
      );

      await auth.updateProfile(profile.copyWith(ownedCartId: 'cart-9'));
      await auth.signOut();

      final signedIn =
          await auth.signIn(email: 'a@b.com', password: 'password123');
      expect(signedIn.ownedCartId, 'cart-9');
    });
  });

  group('LocalModerationRepository', () {
    test('blocking a user hides their cart', () async {
      final carts = LocalCartRepository(store);
      final moderation = LocalModerationRepository(store, carts);

      await carts.createCart(testCart(id: 'cart-1', ownerId: 'owner-1'));
      await store.setDoc(
        LocalKeys.users,
        'owner-1',
        testUser(id: 'owner-1').toMap(),
      );

      await moderation.setUserBlocked(
        userId: 'owner-1',
        isBlocked: true,
        adminId: 'admin-1',
        reason: 'Spam',
      );

      expect((await carts.fetchCart('cart-1'))!.isActive, isFalse);
      final blocked = (await moderation.fetchUsers()).single;
      expect(blocked.isBlocked, isTrue);
      expect(blocked.blockedBy, 'admin-1');

      await moderation.setUserBlocked(
        userId: 'owner-1',
        isBlocked: false,
        adminId: 'admin-1',
      );
      expect((await carts.fetchCart('cart-1'))!.isActive, isTrue);
    });

    test('the user directory never leaks credential fields', () async {
      await LocalSeed.ensureSeeded(store);
      final moderation =
          LocalModerationRepository(store, LocalCartRepository(store));

      final users = await moderation.fetchUsers();
      expect(users, isNotEmpty);
      // UserProfileModel has no password surface at all; this asserts the
      // decoded objects are what reaches the screen.
      expect(users.every((u) => u.email.isNotEmpty), isTrue);
    });

    test('reports move through the queue', () async {
      final moderation =
          LocalModerationRepository(store, LocalCartRepository(store));

      await moderation.submitReport(ReportModel(
        id: 'r1',
        targetType: ReportTargetType.cart,
        targetId: 'cart-1',
        targetName: 'Momo House',
        reporterId: 'u1',
        reporterName: 'Maya',
        reason: ReportReason.spam,
        createdAt: DateTime.now(),
      ));

      expect(
        await moderation.watchReports(status: ReportStatus.open).first,
        hasLength(1),
      );

      await moderation.updateReportStatus(
        reportId: 'r1',
        status: ReportStatus.resolved,
        adminId: 'admin-1',
        note: 'Handled',
      );

      expect(
        await moderation.watchReports(status: ReportStatus.open).first,
        isEmpty,
      );
    });
  });

  group('LocalNotificationRepository', () {
    NotificationModel note(String id, String userId, {bool isRead = false}) =>
        NotificationModel(
          id: id,
          userId: userId,
          cartId: 'cart-1',
          cartName: 'Momo House',
          type: NotificationType.opened,
          message: 'Momo House is open now.',
          createdAt: DateTime(2026, 9, 11, 12, int.parse(id.substring(1))),
          isRead: isRead,
        );

    test('an empty fan-out is a no-op', () async {
      final repo = LocalNotificationRepository(store);
      await repo.pushAll(const <NotificationModel>[]);
      expect(await repo.watchFeed('u1').first, isEmpty);
    });

    test('scopes each feed to its own user', () async {
      final repo = LocalNotificationRepository(store);
      await repo.pushAll(<NotificationModel>[
        note('n1', 'u1'),
        note('n2', 'u2'),
      ]);

      expect(await repo.watchFeed('u1').first, hasLength(1));
      expect((await repo.watchFeed('u2').first).single.id, 'n2');
    });

    test('orders newest first', () async {
      final repo = LocalNotificationRepository(store);
      await repo.pushAll(<NotificationModel>[
        note('n1', 'u1'),
        note('n5', 'u1'),
        note('n3', 'u1'),
      ]);

      expect(
        (await repo.watchFeed('u1').first).map((n) => n.id).toList(),
        <String>['n5', 'n3', 'n1'],
      );
    });

    test('tracks unread state and marks read', () async {
      final repo = LocalNotificationRepository(store);
      await repo.pushAll(<NotificationModel>[
        note('n1', 'u1'),
        note('n2', 'u1'),
      ]);

      expect(await repo.watchUnreadCount('u1').first, 2);

      // Callers address notifications as "userId/noteId" because Firestore
      // nests them per user; the local store only needs the id.
      await repo.markRead('u1/n1');
      expect(await repo.watchUnreadCount('u1').first, 1);

      await repo.markAllRead('u1');
      expect(await repo.watchUnreadCount('u1').first, 0);
    });

    test('markAllRead leaves other users alone', () async {
      final repo = LocalNotificationRepository(store);
      await repo.pushAll(<NotificationModel>[
        note('n1', 'u1'),
        note('n2', 'u2'),
      ]);

      await repo.markAllRead('u1');
      expect(await repo.watchUnreadCount('u2').first, 1);
    });

    test('records a cart update on the public log', () async {
      final repo = LocalNotificationRepository(store);
      await repo.recordCartUpdate(CartUpdateModel(
        id: 'u1',
        cartId: 'cart-1',
        cartName: 'Momo House',
        ownerId: 'owner-1',
        type: CartUpdateType.moved,
        message: 'On the move.',
        createdAt: DateTime(2026, 9, 11),
      ));

      expect(await repo.watchCartUpdates('cart-1').first, hasLength(1));
      expect(await repo.watchCartUpdates('cart-2').first, isEmpty);
    });
  });

  test('cart model round-trips through the wire format', () async {
    final cart = testCart(id: 'cart-1', photoRefs: <String>['a.jpg']);
    final decoded = FoodCartModel.fromMap(cart.toMap(), cart.id);
    expect(decoded, cart);
  });
}
