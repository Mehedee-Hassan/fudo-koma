import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../models/food_cart_model.dart';
import '../repositories/repository_bundle.dart';
import '../state/follow_controller.dart';
import '../theme/app_colors.dart';
import '../theme/cart_palette.dart';
import 'cart_photo.dart';
import 'common.dart';

class CartListTile extends StatelessWidget {
  const CartListTile({
    super.key,
    required this.cart,
    required this.distanceKm,
    this.onTap,
    this.trailing,
  });

  final FoodCartModel cart;
  final double? distanceKm;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final media = context.read<RepositoryBundle>().media;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CartPhoto(cart: cart, media: media, size: 46, radius: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cart.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          DistanceFormat.label(distanceKm),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusDot(isOpen: cart.isOpen),
                      const SizedBox(width: 4),
                      Text(
                        cart.isOpen ? 'Open now' : 'Closed',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}

/// The bottom card on Explore for the selected marker.
class CartDetailCard extends StatelessWidget {
  const CartDetailCard({
    super.key,
    required this.cart,
    required this.distanceKm,
    required this.onFollowPressed,
    this.onOpenDetails,
    this.onClose,
  });

  final FoodCartModel cart;
  final double? distanceKm;
  final VoidCallback onFollowPressed;
  final VoidCallback? onOpenDetails;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final media = context.read<RepositoryBundle>().media;
    final color = CartPalette.colorFor(id: cart.id, category: cart.category);
    final isFollowing = context.select<FollowController, bool>(
      (follows) => follows.isFollowing(cart.id),
    );

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 6,
      child: InkWell(
        onTap: onOpenDetails,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              CartPhoto(cart: cart, media: media),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cart.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cart.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(Icons.near_me, size: 13, color: color),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            DistanceFormat.label(distanceKm),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        StatusDot(isOpen: cart.isOpen),
                        const SizedBox(width: 4),
                        Text(
                          cart.isOpen ? 'Open now' : 'Closed',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onFollowPressed,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isFollowing ? AppColors.primarySoft : AppColors.primary,
                  foregroundColor:
                      isFollowing ? AppColors.primary : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                ),
                child: Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
