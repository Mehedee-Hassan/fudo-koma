import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import 'bootstrap.dart';
import 'repositories/repository_bundle.dart';
import 'repositories/local/local_store.dart';
import 'screens/root_router.dart';
import 'services/alert_cooldown_store.dart';
import 'services/cart_update_publisher.dart';
import 'services/location_service.dart';
import 'services/notification_gateway.dart';
import 'services/proximity_monitor.dart';
import 'state/cart_controller.dart';
import 'state/follow_controller.dart';
import 'state/location_controller.dart';
import 'state/moderation_controller.dart';
import 'state/notification_controller.dart';
import 'state/owner_controller.dart';
import 'state/proximity_controller.dart';
import 'state/session_controller.dart';
import 'theme/app_theme.dart';

/// Everything the app needs is injected here.
///
/// `main()` is the only place that builds the real implementations, which is
/// precisely why widget tests can run without geolocator, shared_preferences,
/// image_picker or flutter_local_notifications ever being touched.
class FolloCartApp extends StatelessWidget {
  const FolloCartApp({
    super.key,
    required this.bundle,
    required this.locationService,
    required this.notifications,
    required this.cooldowns,
    this.store,
    this.tileProvider,
  });

  FolloCartApp.fromDependencies({
    super.key,
    required AppDependencies dependencies,
    required this.locationService,
    this.tileProvider,
  })  : bundle = dependencies.bundle,
        notifications = dependencies.notifications,
        cooldowns = dependencies.cooldowns,
        store = dependencies.store;

  final RepositoryBundle bundle;
  final LocationService locationService;
  final NotificationGateway notifications;
  final AlertCooldownStore cooldowns;
  final LocalStore? store;

  /// Overrides map tile fetching. Tests pass one so `TileLayer` never issues a
  /// real network request.
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
    final publisher = CartUpdatePublisher(
      follows: bundle.follows,
      notifications: bundle.notifications,
    );

    return MultiProvider(
      providers: [
        Provider<RepositoryBundle>.value(value: bundle),
        Provider<LocationService>.value(value: locationService),
        Provider<NotificationGateway>.value(value: notifications),
        Provider<CartUpdatePublisher>.value(value: publisher),
        Provider<TileProvider?>.value(value: tileProvider),

        ChangeNotifierProvider<SessionController>(
          create: (_) => SessionController(bundle.auth, store: store)..restore(),
        ),
        ChangeNotifierProvider<LocationController>(
          create: (_) => LocationController(locationService)..refresh(),
        ),

        // Carts need the user's position to sort by distance.
        ChangeNotifierProxyProvider<LocationController, CartController>(
          create: (_) => CartController(bundle.carts),
          update: (_, location, controller) =>
              controller!..userPosition = location.position,
        ),

        // Everything below is scoped to whoever is signed in. `bindUser` is
        // idempotent, so these run on every rebuild without churning streams.
        ChangeNotifierProxyProvider<SessionController, FollowController>(
          create: (_) => FollowController(bundle.follows),
          update: (_, session, controller) =>
              controller!..bindUser(session.currentUserId),
        ),
        ChangeNotifierProxyProvider<SessionController, NotificationController>(
          create: (_) => NotificationController(bundle.notifications),
          update: (_, session, controller) =>
              controller!..bindUser(session.currentUserId),
        ),
        ChangeNotifierProxyProvider<SessionController, OwnerController>(
          create: (_) => OwnerController(
            carts: bundle.carts,
            media: bundle.media,
            publisher: publisher,
            location: locationService,
            store: store,
          ),
          update: (_, session, controller) => controller!
            ..bindOwner(session.isOwner ? session.currentUserId : null),
        ),
        ChangeNotifierProxyProvider<SessionController, ModerationController>(
          create: (_) => ModerationController(bundle.moderation),
          update: (_, session, controller) => controller!
            ..bindAdmin(session.currentUserId, isAdmin: session.isAdmin),
        ),

        ChangeNotifierProxyProvider4<SessionController, LocationController,
            CartController, FollowController, ProximityController>(
          create: (_) => ProximityController(
            monitor: ProximityMonitor(
              cooldowns: cooldowns,
              gateway: notifications,
              notifications: bundle.notifications,
            ),
            store: store,
          ),
          update: (context, session, location, carts, follows, controller) =>
              controller!
                ..update(
                  userId: session.currentUserId,
                  position: location.position,
                  carts: carts.carts,
                  follows: follows.follows,
                  alertsEnabled:
                      session.profile?.proximityAlertsEnabled ?? false,
                  ownCartId: context.read<OwnerController>().cart?.id,
                ),
        ),
      ],
      child: MaterialApp(
        title: 'Follo Cart',
        debugShowCheckedModeBanner: false,
        theme: FolloTheme.light,
        home: const RootRouter(),
      ),
    );
  }
}
