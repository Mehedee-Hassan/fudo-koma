import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/user_profile_model.dart';
import '../../state/moderation_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';

class UserDirectoryScreen extends StatelessWidget {
  const UserDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final moderation = context.watch<ModerationController>();
    final users = moderation.visibleUsers;

    return Scaffold(
      appBar: AppBar(title: const Text('User directory')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: TextField(
              onChanged: moderation.setUserQuery,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name or email',
              ),
            ),
          ),
          Expanded(
            child: users.isEmpty
                ? const EmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'No accounts found',
                    message: 'Try a different search.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    itemCount: users.length,
                    itemBuilder: (context, index) =>
                        _UserRow(user: users[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});

  final UserProfileModel user;

  @override
  Widget build(BuildContext context) {
    final moderation = context.read<ModerationController>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: user.isBlocked
                  ? AppColors.danger.withValues(alpha: 0.15)
                  : AppColors.primarySoft,
              child: Text(
                user.initials,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color:
                      user.isBlocked ? AppColors.danger : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      RoleBadge(label: user.role.label),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.email.isEmpty
                        ? 'Joined ${RelativeTime.label(user.createdAt)}'
                        : user.email,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (user.isBlocked && user.blockedReason != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Blocked: ${user.blockedReason}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                final failure = await moderation.setBlocked(
                  user: user,
                  isBlocked: !user.isBlocked,
                  reason: user.isBlocked ? null : 'Blocked by admin',
                );
                if (!context.mounted || failure == null) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(failure)));
              },
              child: Text(
                user.isBlocked ? 'Unblock' : 'Block',
                style: TextStyle(
                  color: user.isBlocked ? AppColors.open : AppColors.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
