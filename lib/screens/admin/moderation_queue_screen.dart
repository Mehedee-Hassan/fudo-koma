import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/report_model.dart';
import '../../models/user_profile_model.dart';
import '../../repositories/repository_bundle.dart';
import '../../state/cart_controller.dart';
import '../../state/moderation_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../explore/cart_detail_screen.dart';

class ModerationQueueScreen extends StatelessWidget {
  const ModerationQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final moderation = context.watch<ModerationController>();
    final open = moderation.openReports;

    return Scaffold(
      appBar: AppBar(title: const Text('Moderation queue')),
      body: open.isEmpty
          ? const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Queue is clear',
              message: 'No open reports right now.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              children: [
                for (final report in open)
                  _ReportCard(report: report),
              ],
            ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final ReportModel report;

  @override
  Widget build(BuildContext context) {
    final moderation = context.read<ModerationController>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    report.targetType == ReportTargetType.cart
                        ? Icons.storefront_outlined
                        : Icons.person_outline,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.targetName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${report.reason.label} · reported by '
                        '${report.reporterName} · '
                        '${RelativeTime.label(report.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (report.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  report.note,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (report.targetType == ReportTargetType.cart)
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            CartDetailScreen(cartId: report.targetId),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open'),
                  ),
                if (report.targetType == ReportTargetType.cart)
                  TextButton.icon(
                    onPressed: () => _hideCart(context, report),
                    icon: const Icon(Icons.visibility_off_outlined, size: 16),
                    label: const Text('Hide cart'),
                  ),
                TextButton.icon(
                  onPressed: () => _blockOwner(context, report),
                  icon: const Icon(Icons.block, size: 16),
                  label: const Text('Block owner'),
                ),
                TextButton(
                  onPressed: () => moderation.resolveReport(
                    reportId: report.id,
                    status: ReportStatus.dismissed,
                    note: 'No action needed',
                  ),
                  child: const Text('Dismiss'),
                ),
                FilledButton(
                  onPressed: () => moderation.resolveReport(
                    reportId: report.id,
                    status: ReportStatus.resolved,
                    note: 'Reviewed',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('Resolve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _hideCart(BuildContext context, ReportModel report) async {
    final bundle = context.read<RepositoryBundle>();
    final moderation = context.read<ModerationController>();

    await bundle.carts.setVisibility(cartId: report.targetId, isActive: false);
    await moderation.resolveReport(
      reportId: report.id,
      status: ReportStatus.resolved,
      note: 'Cart hidden from the map',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${report.targetName} is hidden from the map.')),
    );
  }

  Future<void> _blockOwner(BuildContext context, ReportModel report) async {
    final moderation = context.read<ModerationController>();
    final carts = context.read<CartController>();

    final targetUserId = report.targetType == ReportTargetType.user
        ? report.targetId
        : carts.cartById(report.targetId)?.ownerId;

    if (targetUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find that account.')),
      );
      return;
    }

    UserProfileModel? user;
    for (final candidate in moderation.users) {
      if (candidate.id == targetUserId) user = candidate;
    }
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find that account.')),
      );
      return;
    }

    final failure = await moderation.setBlocked(
      user: user,
      isBlocked: true,
      reason: '${report.reason.label} — report ${report.id}',
    );
    if (!context.mounted) return;

    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure)));
      return;
    }

    await moderation.resolveReport(
      reportId: report.id,
      status: ReportStatus.resolved,
      note: 'Owner blocked',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${user.name} has been blocked.')),
    );
  }
}
