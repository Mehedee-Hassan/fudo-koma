import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/notification_controller.dart';
import '../../state/session_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/update_tile.dart';
import '../auth/register_screen.dart';
import '../explore/cart_detail_screen.dart';

class UpdatesScreen extends StatelessWidget {
  const UpdatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final notifications = context.watch<NotificationController>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Latest updates',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (notifications.unreadCount > 0)
              TextButton(
                onPressed: notifications.markAllRead,
                child: const Text('Mark all read'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Your food cart activity in one place.',
          style: TextStyle(color: Colors.grey.shade600, height: 1.4),
        ),
        const SizedBox(height: 22),
        if (session.isGuest)
          EmptyState(
            icon: Icons.notifications_none,
            title: 'Sign in for updates',
            message:
                'Follow a cart and we will tell you when it opens, moves, or '
                'comes within 5 km of you.',
            action: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RegisterScreen(),
                ),
              ),
              child: const Text('Create account'),
            ),
          )
        else if (notifications.isEmpty)
          const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No updates yet',
            message:
                'Once you follow a cart, its opening times, moves and nearby '
                'alerts land here.',
          )
        else
          for (final notification in notifications.feed)
            UpdateTile(
              notification: notification,
              onTap: () {
                notifications.markRead(notification);
                if (notification.cartId.isNotEmpty) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CartDetailScreen(cartId: notification.cartId),
                    ),
                  );
                }
              },
            ),
      ],
    );
  }
}
