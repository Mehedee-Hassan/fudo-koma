import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/notification_model.dart';
import '../theme/app_colors.dart';
import 'common.dart';

class UpdateTile extends StatelessWidget {
  const UpdateTile({super.key, required this.notification, this.onTap});

  final NotificationModel notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _presentation(notification.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.message,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (notification.cartName.isNotEmpty)
                        notification.cartName,
                      RelativeTime.label(notification.createdAt),
                    ].join(' · '),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static (IconData, Color) _presentation(NotificationType type) =>
      switch (type) {
        NotificationType.proximity => (Icons.near_me, AppColors.secondary),
        NotificationType.opened => (Icons.storefront, AppColors.open),
        NotificationType.closed => (Icons.nightlight_round, AppColors.closed),
        NotificationType.moved => (Icons.directions_walk, AppColors.primary),
        NotificationType.scheduleChanged => (Icons.schedule, AppColors.warning),
        NotificationType.announcement => (Icons.campaign_outlined, AppColors.primary),
        NotificationType.system => (Icons.info_outline, AppColors.closed),
      };
}
