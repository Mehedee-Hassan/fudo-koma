import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config/mapbox_config.dart';
import '../core/app_constants.dart';
import '../models/food_cart_model.dart';
import '../theme/app_colors.dart';
import '../theme/cart_palette.dart';

/// The map, extracted so both Explore and the owner's "next stop" picker use
/// one implementation.
///
/// `tileProvider` is injectable purely for tests: `TileLayer` otherwise fires
/// network requests that `flutter_test`'s mock HTTP client answers with 400s,
/// making the suite noisy and intermittently slow.
class CartMap extends StatelessWidget {
  const CartMap({
    super.key,
    required this.carts,
    required this.userLocation,
    this.controller,
    this.initialCenter,
    this.selectedCartId,
    this.onCartTap,
    this.onMapTap,
    this.showRadius = true,
    this.pickedPoint,
    this.tileProvider,
    this.config,
  });

  final List<FoodCartModel> carts;
  final LatLng? userLocation;
  final MapController? controller;

  /// Defaults to the shared constant. The prototype re-declared this literal
  /// inside the build method, so the map always opened on Dhaka.
  final LatLng? initialCenter;

  final String? selectedCartId;
  final ValueChanged<FoodCartModel>? onCartTap;
  final ValueChanged<LatLng>? onMapTap;
  final bool showRadius;
  final LatLng? pickedPoint;
  final TileProvider? tileProvider;
  final MapboxConfig? config;

  @override
  Widget build(BuildContext context) {
    final mapConfig = config ?? MapboxConfig.fromEnvironment();
    final tiles = tileProvider ?? context.read<TileProvider?>();
    final center =
        initialCenter ?? userLocation ?? AppConstants.defaultMapCenter;

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: AppConstants.defaultMapZoom,
        interactionOptions:
            const InteractionOptions(flags: InteractiveFlag.all),
        onTap: onMapTap == null ? null : (_, point) => onMapTap!(point),
      ),
      children: [
        TileLayer(
          urlTemplate: mapConfig.tileUrl,
          userAgentPackageName: 'com.example.follo_cart',
          tileDimension: mapConfig.tileSize,
          zoomOffset: mapConfig.zoomOffset,
          tileProvider: tiles,
        ),
        if (showRadius && userLocation != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: userLocation!,
                radius: AppConstants.alertRadiusMeters,
                useRadiusInMeter: true,
                color: AppColors.radiusFill,
                borderColor: AppColors.radiusStroke,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        if (userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: userLocation!,
                width: 30,
                height: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                ),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final cart in carts)
              Marker(
                point: LatLng(cart.latitude, cart.longitude),
                width: 56,
                height: 68,
                child: GestureDetector(
                  onTap: onCartTap == null ? null : () => onCartTap!(cart),
                  child: _CartMarker(
                    cart: cart,
                    isSelected: cart.id == selectedCartId,
                  ),
                ),
              ),
            if (pickedPoint != null)
              Marker(
                point: pickedPoint!,
                width: 44,
                height: 44,
                child: const Icon(
                  Icons.place,
                  color: AppColors.secondary,
                  size: 40,
                ),
              ),
          ],
        ),
        RichAttributionWidget(
          attributions: [TextSourceAttribution(mapConfig.providerLabel)],
        ),
      ],
    );
  }
}

class _CartMarker extends StatelessWidget {
  const _CartMarker({required this.cart, required this.isSelected});

  final FoodCartModel cart;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final color = CartPalette.colorFor(id: cart.id, category: cart.category);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: isSelected ? 52 : 46,
          height: isSelected ? 52 : 46,
          decoration: BoxDecoration(
            color: cart.isOpen ? color : color.withValues(alpha: 0.55),
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? AppColors.ink : Colors.white,
              width: 3,
            ),
          ),
          child: const Icon(Icons.storefront_rounded,
              color: Colors.white, size: 23),
        ),
        Container(width: 2, height: 7, color: color),
      ],
    );
  }
}
