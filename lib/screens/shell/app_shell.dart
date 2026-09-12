import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/location_controller.dart';
import '../../state/notification_controller.dart';
import '../../state/proximity_controller.dart';
import '../../state/session_controller.dart';
import '../explore/explore_screen.dart';
import '../following/following_screen.dart';
import '../profile/profile_screen.dart';
import '../updates/updates_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedTab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLocationTracking();
  }

  /// Starts and stops the position stream to match the user's alert settings.
  ///
  /// Without this nothing ever subscribes to `watchPosition`, so the proximity
  /// monitor would only ever see the single startup fix and could never fire
  /// as the user moves. `startTracking` is idempotent for an unchanged mode,
  /// so calling it on every dependency change is safe.
  void _syncLocationTracking() {
    final session = context.read<SessionController>();
    final location = context.read<LocationController>();
    final proximity = context.read<ProximityController>();

    final wantsAlerts =
        session.isSignedIn && (session.profile?.proximityAlertsEnabled ?? false);

    if (!wantsAlerts) {
      if (location.isTracking) location.stopTracking();
      return;
    }
    location.startTracking(background: proximity.backgroundAlertsEnabled);
  }

  @override
  Widget build(BuildContext context) {
    // Re-evaluate whenever the session or alert preference changes.
    context.select<SessionController, bool>(
      (session) =>
          session.isSignedIn &&
          (session.profile?.proximityAlertsEnabled ?? false),
    );

    final unread = context.select<NotificationController, int>(
      (notifications) => notifications.unreadCount,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedTab,
          children: const [
            ExploreScreen(),
            FollowingScreen(),
            UpdatesScreen(),
            ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) =>
            setState(() => _selectedTab = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bookmark_outline),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Following',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_none),
            ),
            selectedIcon: const Icon(Icons.notifications),
            label: 'Updates',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
