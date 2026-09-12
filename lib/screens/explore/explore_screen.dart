import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../core/app_constants.dart';
import '../../models/food_cart_model.dart';
import '../../models/food_cart_x.dart';
import '../../state/cart_controller.dart';
import '../../state/follow_controller.dart';
import '../../state/location_controller.dart';
import '../../state/proximity_controller.dart';
import '../../state/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/cart_card.dart';
import '../../widgets/cart_map.dart';
import '../../widgets/common.dart';
import '../common/sign_in_required_sheet.dart';
import 'cart_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  bool _centeredOnUser = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _locateMe() async {
    final location = context.read<LocationController>();
    await location.refresh();
    final position = location.position;
    if (position != null && mounted) {
      _mapController.move(position, AppConstants.defaultMapZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final carts = context.watch<CartController>();
    final location = context.watch<LocationController>();
    final session = context.watch<SessionController>();
    final visible = carts.visibleCarts();

    // Recentre once, the first time a real fix arrives.
    if (!_centeredOnUser && location.hasFix) {
      _centeredOnUser = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(location.position!, AppConstants.defaultMapZoom);
        }
      });
    }

    final selected = carts.selectedCart;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.isGuest
                          ? 'Browsing as guest'
                          : 'Hi, ${session.profile?.name.split(' ').first ?? 'there'}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Find your next bite',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              RoundIconButton(
                icon: carts.openOnly
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
                tooltip: carts.openOnly ? 'Showing open only' : 'Show open only',
                background: carts.openOnly
                    ? AppColors.primarySoft
                    : AppColors.surface,
                foreground:
                    carts.openOnly ? AppColors.primary : AppColors.ink,
                onTap: () => carts.setOpenOnly(!carts.openOnly),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Text(
                  session.profile?.initials ?? 'G',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: TextField(
                    controller: _searchController,
                    onChanged: carts.setQuery,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon:
                          const Icon(Icons.search, color: AppColors.primary),
                      hintText: 'Search food carts',
                      hintStyle: const TextStyle(fontSize: 14),
                      suffixIcon: carts.query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                carts.setQuery('');
                              },
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              RoundIconButton(
                icon: Icons.my_location_rounded,
                tooltip: 'Centre on me',
                background: AppColors.secondarySoft,
                foreground: AppColors.secondary,
                onTap: _locateMe,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text(
                'Near you now',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const Spacer(),
              Text(
                '${visible.length} ${visible.length == 1 ? 'cart' : 'carts'}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: CartMap(
                  carts: visible,
                  userLocation: location.position,
                  controller: _mapController,
                  selectedCartId: carts.selectedCartId,
                  onCartTap: (cart) => carts.select(cart.id),
                  onMapTap: (_) => carts.select(null),
                ),
              ),
              const Positioned(
                top: 18,
                left: 18,
                child: MapPill(icon: Icons.layers_outlined, label: 'Map view'),
              ),
              Positioned(
                top: 18,
                right: 18,
                child: MapPill(
                  icon: Icons.radar_rounded,
                  label: '${AppConstants.alertRadiusKm.round()} km radius',
                ),
              ),
              if (location.isLocating)
                const Positioned(
                  top: 70,
                  left: 18,
                  child: MapPill(
                    icon: Icons.my_location_rounded,
                    label: 'Finding you',
                  ),
                ),
              if (location.error != null && !location.isLocating)
                Positioned(
                  top: 70,
                  left: 18,
                  right: 18,
                  child: _LocationBanner(
                    message: location.error!,
                    onRetry: _locateMe,
                  ),
                ),
              if (selected != null)
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: CartDetailCard(
                    cart: selected,
                    distanceKm: selected.distanceKmFrom(location.position),
                    onOpenDetails: () => _openDetails(selected),
                    onFollowPressed: () => _toggleFollow(selected),
                  ),
                ),
              if (visible.isEmpty && !carts.isLoading)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Material(
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.surface,
                    elevation: 4,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No carts match that search yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _openDetails(FoodCartModel cart) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CartDetailScreen(cartId: cart.id),
      ),
    );
  }

  Future<void> _toggleFollow(FoodCartModel cart) async {
    if (!await ensureSignedIn(context, action: 'follow ${cart.name}')) return;
    if (!mounted) return;

    await context.read<FollowController>().toggle(cart.id);
    if (!mounted) return;

    // A brand-new follow should be able to alert immediately rather than
    // waiting for the next heartbeat.
    await context.read<ProximityController>().evaluate(force: true);
  }
}

class _LocationBanner extends StatelessWidget {
  const _LocationBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.location_off_outlined,
                color: AppColors.secondary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$message Showing the demo area.',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
