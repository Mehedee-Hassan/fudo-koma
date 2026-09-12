import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/food_cart_x.dart';
import '../../state/cart_controller.dart';
import '../../state/follow_controller.dart';
import '../../state/location_controller.dart';
import '../../state/session_controller.dart';
import '../../widgets/cart_card.dart';
import '../../widgets/common.dart';
import '../auth/register_screen.dart';
import '../explore/cart_detail_screen.dart';

class FollowingScreen extends StatelessWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final follows = context.watch<FollowController>();
    final carts = context.watch<CartController>();
    final location = context.watch<LocationController>();

    if (session.isGuest) {
      return _Page(
        title: 'Your followed carts',
        subtitle: 'Follow carts to see them here.',
        children: [
          EmptyState(
            icon: Icons.bookmark_outline,
            title: 'Sign in to follow carts',
            message:
                'Your follows and alerts are tied to your account, so they '
                'travel with you to any device.',
            action: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RegisterScreen(),
                ),
              ),
              child: const Text('Create account'),
            ),
          ),
        ],
      );
    }

    final followed = follows.followedCartIds;
    final followedCarts = carts.carts
        .where((cart) => followed.contains(cart.id))
        .toList()
      ..sort((a, b) {
        final da = a.distanceKmFrom(location.position) ?? double.infinity;
        final db = b.distanceKmFrom(location.position) ?? double.infinity;
        return da.compareTo(db);
      });

    return _Page(
      title: 'Your followed carts',
      subtitle:
          'Get notified when they move, open, or update their schedule.',
      children: [
        if (followedCarts.isEmpty)
          const EmptyState(
            icon: Icons.explore_outlined,
            title: 'Nothing followed yet',
            message:
                'Open Explore, tap a cart on the map, and hit Follow to start '
                'getting updates.',
          )
        else
          for (final cart in followedCarts)
            CartListTile(
              cart: cart,
              distanceKm: cart.distanceKmFrom(location.position),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CartDetailScreen(cartId: cart.id),
                ),
              ),
            ),
      ],
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600, height: 1.4),
        ),
        const SizedBox(height: 22),
        ...children,
      ],
    );
  }
}
