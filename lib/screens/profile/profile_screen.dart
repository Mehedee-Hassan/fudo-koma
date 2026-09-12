import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_constants.dart';
import '../../repositories/repository_bundle.dart';
import '../../state/follow_controller.dart';
import '../../state/proximity_controller.dart';
import '../../state/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../admin/admin_dashboard_screen.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../owner/owner_dashboard_screen.dart';
import 'notification_settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final mode = context.read<RepositoryBundle>().mode;
    final profile = session.profile;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Your profile',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            BackendModeBadge(label: mode.label, isLocal: mode.isLocal),
          ],
        ),
        const SizedBox(height: 18),
        if (session.isGuest)
          const _GuestCard()
        else if (profile != null)
          SectionCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    profile.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        profile.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RoleBadge(label: profile.role.label),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),

        // Role workspaces are cards here rather than extra tabs: a
        // role-dependent tab index would break deep links and muscle memory.
        if (session.isOwner) ...[
          _WorkspaceCard(
            icon: Icons.storefront_outlined,
            title: 'Cart owner studio',
            detail:
                'Share your live location, set open hours, and publish your '
                'next stop.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const OwnerDashboardScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (session.isAdmin) ...[
          _WorkspaceCard(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Admin console',
            detail:
                'Review reports, hide carts, and block abusive accounts.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AdminDashboardScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],

        if (!session.isGuest) ...[
          const SizedBox(height: 6),
          const _StatsRow(),
          const SizedBox(height: 18),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.notifications_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Notifications',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Schedule, opening status, and '
                    '${AppConstants.alertRadiusKm.round()} km nearby alerts',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.logout,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Sign out',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: session.signOut,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          mode.isLocal
              ? 'Local mode stores everything on this device. Follows and '
                  'updates survive restarts, but do not sync to other devices. '
                  'See SETUP_FIREBASE.md to connect a backend.'
              : 'Connected to Firebase. Your account and follows sync across '
                  'your devices.',
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Browsing as guest',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'You can explore the map and search carts. Create an account to '
            'follow carts and get alerts.',
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RegisterScreen(),
                    ),
                  ),
                  child: const Text('Create account'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                  ),
                  child: const Text('Sign in'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final follows = context.watch<FollowController>();
    final proximity = context.watch<ProximityController>();

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Following',
            value: '${follows.follows.length}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'Alert radius',
            value: '${AppConstants.alertRadiusKm.round()} km',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'Background',
            value: proximity.backgroundAlertsEnabled ? 'On' : 'Off',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
        ],
      ),
    );
  }
}
