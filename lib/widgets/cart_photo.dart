import 'package:flutter/material.dart';

import '../models/food_cart_model.dart';
import '../repositories/media_repository.dart';
import '../theme/cart_palette.dart';

/// Renders a `MediaRepository` reference, falling back to the cart's palette
/// colour and a glyph when there is no photo yet.
class CartPhoto extends StatelessWidget {
  const CartPhoto({
    super.key,
    required this.cart,
    required this.media,
    this.size = 52,
    this.radius = 15,
    this.photoRef,
  });

  final FoodCartModel cart;
  final MediaRepository media;
  final double size;
  final double radius;
  final String? photoRef;

  @override
  Widget build(BuildContext context) {
    final color = CartPalette.colorFor(id: cart.id, category: cart.category);
    final reference = photoRef ?? cart.primaryPhotoRef;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: reference == null
            ? Container(
                color: color.withValues(alpha: 0.14),
                child: Icon(Icons.restaurant_rounded,
                    color: color, size: size * 0.52),
              )
            : Image(
                image: media.imageFor(reference),
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) => Container(
                  color: color.withValues(alpha: 0.14),
                  child: Icon(Icons.broken_image_outlined,
                      color: color, size: size * 0.45),
                ),
              ),
      ),
    );
  }
}
