import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/food_cart_model.dart';
import '../../models/food_cart_x.dart';
import '../../models/report_model.dart';
import '../../models/schedule_entry_model.dart';
import '../../repositories/repository_bundle.dart';
import '../../state/cart_controller.dart';
import '../../state/follow_controller.dart';
import '../../state/location_controller.dart';
import '../../state/proximity_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/cart_palette.dart';
import '../../widgets/common.dart';
import '../common/report_sheet.dart';
import '../common/sign_in_required_sheet.dart';

class CartDetailScreen extends StatelessWidget {
  const CartDetailScreen({super.key, required this.cartId});

  final String cartId;

  @override
  Widget build(BuildContext context) {
    final carts = context.watch<CartController>();
    final cart = carts.cartById(cartId);

    if (cart == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.storefront_outlined,
          title: 'Cart unavailable',
          message: 'This cart is no longer listed.',
        ),
      );
    }

    final location = context.watch<LocationController>();
    final follows = context.watch<FollowController>();
    final media = context.read<RepositoryBundle>().media;
    final color = CartPalette.colorFor(id: cart.id, category: cart.category);
    final isFollowing = follows.isFollowing(cart.id);
    final follow = follows.followFor(cart.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(cart.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report this cart',
            onPressed: () => _report(context, cart),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (cart.hasPhotos)
            SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cart.photoRefs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image(
                    image: media.imageFor(cart.photoRefs[index]),
                    width: 240,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 240,
                      color: color.withValues(alpha: 0.12),
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.restaurant_rounded, size: 44, color: color),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  cart.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusDot(isOpen: cart.isOpen, size: 9),
              const SizedBox(width: 6),
              Text(
                cart.isOpen ? 'Open now' : 'Closed',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            cart.category,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          if (cart.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(cart.description, style: const TextStyle(height: 1.5)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _toggleFollow(context, cart),
              style: FilledButton.styleFrom(
                backgroundColor:
                    isFollowing ? AppColors.primarySoft : AppColors.primary,
                foregroundColor:
                    isFollowing ? AppColors.primary : Colors.white,
              ),
              icon: Icon(
                isFollowing ? Icons.check : Icons.add,
                size: 18,
              ),
              label: Text(isFollowing ? 'Following' : 'Follow this cart'),
            ),
          ),
          const SizedBox(height: 18),
          _InfoRow(
            icon: Icons.near_me,
            label: 'Distance',
            value: DistanceFormat.label(
              cart.distanceKmFrom(location.position),
            ),
          ),
          _InfoRow(
            icon: Icons.place_outlined,
            label: 'Where',
            value: cart.locationLabel,
          ),
          _InfoRow(
            icon: Icons.schedule,
            label: 'Today',
            value: cart.scheduleSummary(),
          ),
          _InfoRow(
            icon: Icons.people_outline,
            label: 'Followers',
            value: '${cart.followersCount}',
          ),
          if (cart.lastLocationAt case final at?)
            _InfoRow(
              icon: Icons.gps_fixed,
              label: 'Location updated',
              value: RelativeTime.label(at),
            ),
          if (cart.nextStop case final next?) ...[
            const SizedBox(height: 8),
            SectionCard(
              child: Row(
                children: [
                  const Icon(Icons.flag_outlined, color: AppColors.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Next stop',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${next.locationLabel} · ${next.timeLabel()}',
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
            ),
          ],
          if (isFollowing && follow != null) ...[
            const SizedBox(height: 20),
            const Text(
              'Alerts for this cart',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notify me about this cart'),
              subtitle: const Text('Opening, schedule and nearby alerts'),
              value: follow.notificationsEnabled,
              onChanged: (value) => context
                  .read<FollowController>()
                  .setNotificationsEnabled(cart.id, value),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Alert radius'),
              subtitle: Text('${follow.proximityAlertKm} km'),
            ),
            Slider(
              value: follow.proximityAlertKm.toDouble().clamp(1, 10),
              min: 1,
              max: 10,
              divisions: 9,
              label: '${follow.proximityAlertKm} km',
              onChanged: (value) => context
                  .read<FollowController>()
                  .setProximityKm(cart.id, value.round()),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Weekly schedule',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (cart.scheduleEntries.isEmpty)
            Text(
              'This cart has not published a schedule yet.',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            ..._weeklyRows(cart),
        ],
      ),
    );
  }

  List<Widget> _weeklyRows(FoodCartModel cart) {
    const names = <int, String>{
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
      DateTime.sunday: 'Sun',
    };

    final weekly = cart.scheduleEntries.where((e) => !e.isOneOff).toList();
    return <Widget>[
      for (var weekday = DateTime.monday;
          weekday <= DateTime.sunday;
          weekday++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  names[weekday]!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                _labelFor(weekly, weekday),
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
    ];
  }

  static String _labelFor(List<ScheduleEntry> entries, int weekday) {
    final matches =
        entries.where((e) => e.weekday == weekday && e.isActive).toList();
    if (matches.isEmpty) return 'Closed';
    return matches.map((e) => e.timeLabel()).join(', ');
  }

  Future<void> _toggleFollow(BuildContext context, FoodCartModel cart) async {
    if (!await ensureSignedIn(context, action: 'follow ${cart.name}')) return;
    if (!context.mounted) return;

    await context.read<FollowController>().toggle(cart.id);
    if (!context.mounted) return;
    await context.read<ProximityController>().evaluate(force: true);
  }

  Future<void> _report(BuildContext context, FoodCartModel cart) async {
    if (!await ensureSignedIn(context, action: 'report a cart')) return;
    if (!context.mounted) return;

    await showReportSheet(
      context,
      targetType: ReportTargetType.cart,
      targetId: cart.id,
      targetName: cart.name,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
