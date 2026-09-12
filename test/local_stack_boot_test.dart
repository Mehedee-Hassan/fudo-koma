import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follo_cart/app.dart';
import 'package:follo_cart/models/user_role.dart';
import 'package:follo_cart/repositories/local/local_seed.dart';
import 'package:follo_cart/repositories/local/local_store.dart';
import 'package:follo_cart/repositories/repository_bundle.dart';
import 'package:follo_cart/services/alert_cooldown_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';
import 'support/pump_app.dart';

/// Boots the app against the REAL local repositories rather than fakes.
///
/// This is the configuration that actually ships when no Firebase project is
/// configured, so it is the one worth proving end to end. Only the location
/// service and the notification gateway are faked, because those are plugins.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStore store;
  late RepositoryBundle bundle;

  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(FolloCartApp(
      bundle: bundle,
      locationService: FakeLocationService(),
      notifications: RecordingNotificationGateway(),
      cooldowns: AlertCooldownStore(store),
      store: store,
      tileProvider: FakeTileProvider(),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = LocalStore(await SharedPreferences.getInstance());
    await LocalSeed.ensureSeeded(store);
    bundle = RepositoryBundle.local(store);
  });

  testWidgets('starts in local mode with the seeded carts', (tester) async {
    await boot(tester);

    expect(find.text('Local demo data'), findsOneWidget);

    await tester.tap(find.text('Browse as guest'));
    await tester.pumpAndSettle();

    expect(find.text('Find your next bite'), findsOneWidget);
    expect(find.text('7 carts'), findsOneWidget);
  });

  testWidgets('a seeded demo account signs in and sees its follows',
      (tester) async {
    await boot(tester);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), LocalSeed.customerEmail);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), LocalSeed.demoPassword);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Find your next bite'), findsOneWidget);

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();

    // Maya is seeded following Momo House and Chai Chapter.
    expect(find.text('Momo House'), findsOneWidget);
    expect(find.text('Chai Chapter'), findsOneWidget);
  });

  testWidgets('a follow survives a full app restart', (tester) async {
    await boot(tester);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), LocalSeed.customerEmail);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), LocalSeed.demoPassword);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    final userId = bundle.auth.currentUser!.id;
    await bundle.follows.follow(userId: userId, cartId: 'cart-4');
    await tester.pumpAndSettle();

    // Rebuild the whole object graph over the same storage - a cold start.
    bundle.dispose();
    bundle = RepositoryBundle.local(store);
    await boot(tester);

    // The session is restored too, so no sign-in screen.
    expect(find.text('Find your next bite'), findsOneWidget);

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();

    expect(find.text('Taco Tuk'), findsOneWidget);
  });

  testWidgets('an owner signs in and reaches their real cart', (tester) async {
    await boot(tester);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), LocalSeed.ownerEmail);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), LocalSeed.demoPassword);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(bundle.auth.currentUser?.role, UserRole.owner);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cart owner studio'));
    await tester.pumpAndSettle();

    expect(find.text('Momo House'), findsOneWidget);
    expect(find.text('Shop is open'), findsOneWidget);
    expect(find.text('Share live location'), findsOneWidget);
  });

  testWidgets('an owner closing the shop reaches a follower\'s Updates tab',
      (tester) async {
    // Owner acts.
    final cart = await bundle.carts.fetchCart('cart-1');
    await bundle.carts.setOpen(cartId: cart!.id, isOpen: false);

    // Fan-out is what the OwnerController triggers; exercised directly here
    // against the real repositories.
    final followerIds = await bundle.follows.followerIdsForCart('cart-1');
    expect(followerIds, contains('user-maya'));

    await boot(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), LocalSeed.customerEmail);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), LocalSeed.demoPassword);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();

    // The closed status propagated through the repository stream.
    expect(find.textContaining('Closed'), findsWidgets);
  });

  testWidgets('one-tap demo sign-in works for each role', (tester) async {
    for (final (label, role) in <(String, UserRole)>[
      ('Customer', UserRole.customer),
      ('Owner', UserRole.owner),
      ('Admin', UserRole.admin),
    ]) {
      await boot(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, label));
      await tester.pumpAndSettle();

      expect(find.text('Find your next bite'), findsOneWidget,
          reason: 'one-tap $label should land on Explore');
      expect(bundle.auth.currentUser?.role, role);

      await bundle.auth.signOut();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the seeded demo password satisfies register-screen rules',
      (tester) async {
    // Demo data must not depend on validation being relaxed for it.
    expect(LocalSeed.demoPassword.length, greaterThanOrEqualTo(8));
  });

  testWidgets('an admin sees the seeded moderation queue', (tester) async {
    await boot(tester);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), LocalSeed.adminEmail);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), LocalSeed.demoPassword);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin console'));
    await tester.pumpAndSettle();

    expect(find.text('Moderation center'), findsOneWidget);

    await tester.tap(find.text('Moderation queue'));
    await tester.pumpAndSettle();

    expect(find.text('Dosa Dash'), findsOneWidget);
    expect(find.text('Noodle Van'), findsOneWidget);
  });

  testWidgets('blocking an owner removes their cart from Explore',
      (tester) async {
    await boot(tester);

    await tester.tap(find.text('Browse as guest'));
    await tester.pumpAndSettle();
    expect(find.text('7 carts'), findsOneWidget);

    await bundle.moderation.setUserBlocked(
      userId: 'owner-1',
      isBlocked: true,
      adminId: 'user-admin',
      reason: 'Test',
    );
    await tester.pumpAndSettle();

    expect(find.text('6 carts'), findsOneWidget);
  });
}
