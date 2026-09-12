import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_constants.dart';
import '../../services/notification_gateway.dart';
import '../../state/follow_controller.dart';
import '../../state/location_controller.dart';
import '../../state/proximity_controller.dart';
import '../../state/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final proximity = context.watch<ProximityController>();
    final follows = context.watch<FollowController>();
    final profile = session.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Nearby cart alerts',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'Tell me when a cart I follow is within '
              '${AppConstants.alertRadiusKm.round()} km.',
            ),
            value: profile?.proximityAlertsEnabled ?? false,
            onChanged: (value) async {
              await session.setProximityAlertsEnabled(value);
              if (value && context.mounted) {
                await context.read<NotificationGateway>().requestPermission();
              }
            },
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Keep alerting in the background',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Runs a location service so alerts keep working when the app is '
              'not open. Uses more battery.',
            ),
            value: proximity.backgroundAlertsEnabled,
            onChanged: (profile?.proximityAlertsEnabled ?? false)
                ? (value) async {
                    await proximity.setBackgroundAlertsEnabled(value);
                    if (!context.mounted) return;
                    final location = context.read<LocationController>();
                    if (value) {
                      await location.startTracking(background: true);
                    } else {
                      await location.startTracking();
                    }
                  }
                : null,
          ),
          const SizedBox(height: 8),
          const _PlatformLimitsNote(),
          const SizedBox(height: 24),
          const Text(
            'Per-cart alerts',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Open a cart to change its alert radius.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (follows.follows.isEmpty)
            const EmptyState(
              icon: Icons.bookmark_outline,
              title: 'No follows yet',
              message: 'Follow a cart to tune its alerts.',
            )
          else
            for (final follow in follows.follows)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Cart ${follow.cartId}'),
                subtitle: Text('Alerts within ${follow.proximityAlertKm} km'),
                value: follow.notificationsEnabled,
                onChanged: (value) => follows.setNotificationsEnabled(
                  follow.cartId,
                  value,
                ),
              ),
        ],
      ),
    );
  }
}

/// Says plainly what each platform can and cannot do, rather than implying a
/// guarantee the OS will not honour.
class _PlatformLimitsNote extends StatelessWidget {
  const _PlatformLimitsNote();

  @override
  Widget build(BuildContext context) {
    final text = switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        'On Android this runs a foreground service with a persistent '
            'notification. Some phones still stop it when you swipe the app '
            'away.',
      TargetPlatform.iOS =>
        'On iOS, alerts work while the app is open or recently backgrounded. '
            'A fully closed app cannot run location checks - that needs server '
            'push, which is not connected yet.',
      _ => 'On the web, alerts appear in the app while it is open.',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 17, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
