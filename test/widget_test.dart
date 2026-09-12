import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follo_cart/models/food_cart_model.dart';
import 'package:follo_cart/models/report_model.dart';
import 'package:follo_cart/models/user_profile_model.dart';
import 'package:follo_cart/models/user_role.dart';
import 'package:latlong2/latlong.dart';

import 'support/fakes.dart';
import 'support/pump_app.dart';

/// End-to-end coverage of the eight roadmap features, driven through the real
/// widget tree against fake repositories. No plugin is touched.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final seededCarts = <FoodCartModel>[
    testCart(id: 'cart-1', name: 'Momo House', latitude: 23.8130),
    testCart(id: 'cart-2', name: 'The Green Bowl', latitude: 23.8125),
    testCart(id: 'cart-3', name: 'Chai Chapter', latitude: 23.8065),
  ];

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('guest browsing', () {
    testWidgets('welcome screen offers the three entry points', (tester) async {
      final fakes = fakeBundle(carts: seededCarts);
      await pumpApp(tester, bundle: fakes.bundle);
      await tester.pumpAndSettle();

      expect(find.text('Follo Cart'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Browse as guest'), findsOneWidget);
    });

    testWidgets('browse as guest reaches Explore with the seeded carts',
        (tester) async {
      final fakes = fakeBundle(carts: seededCarts);
      await pumpApp(tester, bundle: fakes.bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Browse as guest'));
      await tester.pumpAndSettle();

      expect(find.text('Find your next bite'), findsOneWidget);
      expect(find.text('Near you now'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('3 carts'), findsOneWidget);
      expect(find.text('Browsing as guest'), findsOneWidget);
    });

    testWidgets('a guest is asked to sign in before following', (tester) async {
      final fakes = fakeBundle(carts: seededCarts);
      await pumpApp(tester, bundle: fakes.bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Browse as guest'));
      await tester.pumpAndSettle();
      await tapTab(tester, 'Following');

      expect(find.text('Sign in to follow carts'), findsOneWidget);
      expect(fakes.follows.current, isEmpty);
    });
  });

  group('auth and roles', () {
    testWidgets('registering as a customer signs the user in', (tester) async {
      final fakes = fakeBundle(carts: seededCarts);
      await pumpApp(tester, bundle: fakes.bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Your name'), 'Maya');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'maya@example.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'password123',
      );

      // The submit button sits below the fold on a test-sized screen, and the
      // ListView builds lazily, so it must be scrolled into existence first.
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Find your next bite'), findsOneWidget);
      expect(fakes.auth.currentUser?.name, 'Maya');
      expect(fakes.auth.currentUser?.role, UserRole.customer);
    });

    testWidgets('admin is not offered at registration by default',
        (tester) async {
      final fakes = fakeBundle(carts: seededCarts);
      await pumpApp(tester, bundle: fakes.bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Cart owner'), findsOneWidget);
      // Without an ADMIN_CODE dart-define, admin must never be self-service.
      expect(find.text('Admin'), findsNothing);
    });

    testWidgets('a blocked account cannot sign in', (tester) async {
      final fakes = fakeBundle(carts: seededCarts);
      fakes.auth.seedAccount(
        testUser(id: 'u-blocked', email: 'blocked@example.com', isBlocked: true),
        'password123',
      );
      await pumpApp(tester, bundle: fakes.bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'blocked@example.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Blocked'), findsOneWidget);
      expect(fakes.auth.currentUser, isNull);
    });

    testWidgets('role decides which workspace cards appear', (tester) async {
      final owner = testUser(id: 'owner-1', role: UserRole.owner);
      final fakes = fakeBundle(carts: seededCarts, signedInAs: owner);
      await pumpApp(tester, bundle: fakes.bundle);
      await tester.pumpAndSettle();

      await tapTab(tester, 'Profile');

      expect(find.text('Cart owner studio'), findsOneWidget);
      expect(find.text('Admin console'), findsNothing);
    });
  });

  group('follows persist through the repository', () {
    testWidgets('following a cart adds it to the Following tab',
        (tester) async {
      final customer = testUser(id: 'u1', role: UserRole.customer);
      final fakes = fakeBundle(carts: seededCarts, signedInAs: customer);
      await pumpApp(tester, bundle: fakes.bundle);
      await tester.pumpAndSettle();

      await fakes.bundle.follows.follow(userId: 'u1', cartId: 'cart-1');
      await tester.pumpAndSettle();

      await tapTab(tester, 'Following');

      expect(find.text('Momo House'), findsOneWidget);
      expect(find.text('The Green Bowl'), findsNothing);
      // The counter is adjusted through the repository, not in memory.
      expect(fakes.carts.current.first.followersCount, 1);
    });

    testWidgets('unfollowing removes it again', (tester) async {
      final customer = testUser(id: 'u1');
      final fakes = fakeBundle(carts: seededCarts, signedInAs: customer);
      await pumpApp(tester, bundle: fakes.bundle);
      await tester.pumpAndSettle();

      await fakes.bundle.follows.follow(userId: 'u1', cartId: 'cart-1');
      await tester.pumpAndSettle();
      await fakes.bundle.follows.unfollow(userId: 'u1', cartId: 'cart-1');
      await tester.pumpAndSettle();

      await tapTab(tester, 'Following');
      expect(find.text('Nothing followed yet'), findsOneWidget);
    });
  });

  group('owner updates fan out to followers', () {
    testWidgets('opening the shop lands in a follower\'s Updates tab',
        (tester) async {
      final follower = testUser(id: 'u1');
      final fakes = fakeBundle(
        carts: <FoodCartModel>[
          testCart(id: 'cart-1', name: 'Momo House', isOpen: false),
        ],
        signedInAs: follower,
      );
      await pumpApp(tester, bundle: fakes.bundle);
      await tester.pumpAndSettle();

      await fakes.bundle.follows.follow(userId: 'u1', cartId: 'cart-1');
      await tester.pumpAndSettle();

      // The owner acts from their own session; the fan-out writes into every
      // follower's inbox.
      await fakes.bundle.carts.setOpen(cartId: 'cart-1', isOpen: true);

      await tester.pumpAndSettle();

      expect(await fakes.bundle.follows.followerIdsForCart('cart-1'),
          <String>['u1']);
    });
  });

  group('admin moderation', () {
    testWidgets('the console shows real counts and the queue', (tester) async {
      final admin = testUser(id: 'admin-1', role: UserRole.admin);
      final reported = testUser(id: 'owner-1', role: UserRole.owner);

      final fakes = fakeBundle(
        carts: seededCarts,
        signedInAs: admin,
        users: <UserProfileModel>[admin, reported],
        reports: <ReportModel>[
          ReportModel(
            id: 'r1',
            targetType: ReportTargetType.cart,
            targetId: 'cart-1',
            targetName: 'Momo House',
            reporterId: 'u1',
            reporterName: 'Maya',
            reason: ReportReason.wrongLocation,
            note: 'Pin is two streets off.',
            createdAt: DateTime(2026, 9, 10),
          ),
        ],
      );

      await pumpApp(tester, bundle: fakes.bundle);
      await tester.pumpAndSettle();

      await tapTab(tester, 'Profile');
      await tester.tap(find.text('Admin console'));
      await tester.pumpAndSettle();

      expect(find.text('Moderation center'), findsOneWidget);
      expect(find.text('Open reports'), findsOneWidget);
      // The prototype showed invented totals; these are derived from the data.
      expect(find.text('1'), findsWidgets);

      await tester.tap(find.text('Moderation queue'));
      await tester.pumpAndSettle();

      expect(find.text('Momo House'), findsOneWidget);
      expect(find.text('Pin is two streets off.'), findsOneWidget);
    });

    testWidgets('blocking an owner hides their cart from the map',
        (tester) async {
      final admin = testUser(id: 'admin-1', role: UserRole.admin);
      final owner = testUser(id: 'owner-1', role: UserRole.owner);

      final fakes = fakeBundle(
        carts: <FoodCartModel>[
          testCart(id: 'cart-1', name: 'Momo House', ownerId: 'owner-1'),
          testCart(id: 'cart-2', name: 'The Green Bowl', ownerId: 'owner-2'),
        ],
        signedInAs: admin,
        users: <UserProfileModel>[admin, owner],
      );

      await pumpApp(tester, bundle: fakes.bundle);
      await tester.pumpAndSettle();
      expect(find.text('2 carts'), findsOneWidget);

      await fakes.bundle.moderation.setUserBlocked(
        userId: 'owner-1',
        isBlocked: true,
        adminId: 'admin-1',
        reason: 'Spam',
      );
      await tester.pumpAndSettle();

      expect(find.text('1 cart'), findsOneWidget);
      expect(
        fakes.carts.current.firstWhere((c) => c.id == 'cart-1').isActive,
        isFalse,
      );
    });

    testWidgets('an admin cannot block the last remaining admin',
        (tester) async {
      final admin = testUser(id: 'admin-1', role: UserRole.admin);
      final fakes = fakeBundle(
        carts: seededCarts,
        signedInAs: admin,
        users: <UserProfileModel>[admin],
      );

      await pumpApp(tester, bundle: fakes.bundle);
      await tester.pumpAndSettle();
      await tapTab(tester, 'Profile');
      await tester.tap(find.text('Admin console'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('User directory'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();

      expect(find.textContaining('own account'), findsOneWidget);
      expect(fakes.moderation.users.single.isBlocked, isFalse);
    });
  });

  group('proximity alerts', () {
    testWidgets('moving near a followed cart fires exactly one notification',
        (tester) async {
      final customer = testUser(id: 'u1');
      final gateway = RecordingNotificationGateway();
      final location = FakeLocationService(
        initial: const LatLng(24.5000, 90.4125), // far away
      );

      final fakes = fakeBundle(
        carts: <FoodCartModel>[
          testCart(id: 'cart-1', name: 'Momo House', latitude: 23.8130),
        ],
        signedInAs: customer,
      );

      await pumpApp(
        tester,
        bundle: fakes.bundle,
        location: location,
        notifications: gateway,
      );
      await tester.pumpAndSettle();

      await fakes.bundle.follows.follow(userId: 'u1', cartId: 'cart-1');
      await tester.pumpAndSettle();
      gateway.shown.clear();

      // Walk into range.
      location.emit(const LatLng(23.8103, 90.4125));
      await tester.pumpAndSettle();

      expect(gateway.shown, hasLength(1));
      expect(gateway.shown.single.title, contains('Momo House'));
      // Real distance, not the old clamped "5.0 km".
      expect(gateway.shown.single.body, isNot(contains('5.0 km')));

      // A small further move must not re-alert - that is the cooldown.
      location.emit(const LatLng(23.8104, 90.4126));
      await tester.pumpAndSettle();
      expect(gateway.shown, hasLength(1));
    });

    testWidgets('no alert fires for a cart the user does not follow',
        (tester) async {
      final customer = testUser(id: 'u1');
      final gateway = RecordingNotificationGateway();
      final location = FakeLocationService(
        initial: const LatLng(24.5000, 90.4125),
      );

      final fakes = fakeBundle(
        carts: <FoodCartModel>[
          testCart(id: 'cart-1', name: 'Momo House', latitude: 23.8130),
        ],
        signedInAs: customer,
      );

      await pumpApp(
        tester,
        bundle: fakes.bundle,
        location: location,
        notifications: gateway,
      );
      await tester.pumpAndSettle();

      location.emit(const LatLng(23.8103, 90.4125));
      await tester.pumpAndSettle();

      expect(gateway.shown, isEmpty);
    });
  });

  group('live distances', () {
    testWidgets('Explore renders a computed distance, not a fixed string',
        (tester) async {
      final customer = testUser(id: 'u1');
      final location = FakeLocationService(
        initial: const LatLng(23.8103, 90.4125),
      );

      final fakes = fakeBundle(
        carts: <FoodCartModel>[
          // ~0.3 km north of the user.
          testCart(id: 'cart-1', name: 'Momo House', latitude: 23.8130),
        ],
        signedInAs: customer,
      );

      await pumpApp(tester, bundle: fakes.bundle, location: location);
      await tester.pumpAndSettle();

      await fakes.bundle.follows.follow(userId: 'u1', cartId: 'cart-1');
      await tester.pumpAndSettle();
      await tapTab(tester, 'Following');

      // Sub-kilometre distances render in metres.
      expect(find.textContaining(RegExp(r'\d+ m away')), findsOneWidget);
      expect(find.text('0.8 km away'), findsNothing);
    });
  });
}
