import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/cart_controller.dart';
import '../../state/moderation_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import 'moderation_queue_screen.dart';
import 'user_directory_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final moderation = context.watch<ModerationController>();
    final carts = context.watch<CartController>();

    // Every number here is derived from the repositories. The prototype
    // displayed invented totals ("128", "12.4k") with no data behind them.
    final allCarts = carts.carts;
    final hiddenCount = moderation.users.isEmpty ? 0 : _hiddenCount(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin console')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          const Text(
            'Moderation center',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Review reports and protect the marketplace.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Open reports',
                  value: '${moderation.openReports.length}',
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'Active carts',
                  value: '${allCarts.length}',
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Users',
                  value: '${moderation.users.length}',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'Blocked',
                  value: '${moderation.blockedUserCount}',
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          if (hiddenCount > 0) ...[
            const SizedBox(height: 12),
            _StatTile(
              label: 'Hidden carts',
              value: '$hiddenCount',
              color: AppColors.warning,
            ),
          ],
          const SizedBox(height: 24),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.flag_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Moderation queue',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${moderation.openReports.length} awaiting review',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ModerationQueueScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.people_outline,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'User directory',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Search, block, and unblock accounts'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const UserDirectoryScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Blocking takes effect immediately: the account cannot sign in, an '
            'open session is ended, and their cart leaves the map. In Firebase '
            'mode this is backed by Security Rules — see SETUP_FIREBASE.md.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  static int _hiddenCount(BuildContext context) {
    // CartController filters hidden carts out of `carts`, so count them from
    // the moderation side instead of reaching past that filter.
    final blocked = context
        .read<ModerationController>()
        .users
        .where((u) => u.isBlocked && u.ownedCartId != null)
        .length;
    return blocked;
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
