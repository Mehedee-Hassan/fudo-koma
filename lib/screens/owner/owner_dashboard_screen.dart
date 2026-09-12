import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/cart_update_model.dart';
import '../../models/food_cart_x.dart';
import '../../repositories/repository_bundle.dart';
import '../../state/owner_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/cart_map.dart';
import '../../widgets/cart_photo.dart';
import '../../widgets/common.dart';
import 'cart_editor_screen.dart';
import 'claim_cart_screen.dart';
import 'schedule_editor_screen.dart';

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final owner = context.watch<OwnerController>();
    final bundle = context.read<RepositoryBundle>();

    if (owner.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cart owner studio')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final cart = owner.cart;
    if (cart == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cart owner studio')),
        body: EmptyState(
          icon: Icons.storefront_outlined,
          title: 'No cart yet',
          message:
              'Create your cart so customers can find you on the map and '
              'follow your updates.',
          action: Column(
            children: [
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const CartEditorScreen(mode: CartEditorMode.create),
                  ),
                ),
                child: const Text('Create my cart'),
              ),
              // Demo affordance: lets a walkthrough drive the seeded cart that
              // already has followers and history.
              if (kDebugMode && bundle.mode.isLocal)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ClaimCartScreen(),
                    ),
                  ),
                  child: const Text('Claim a demo cart'),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart owner studio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit cart details',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const CartEditorScreen(mode: CartEditorMode.edit),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          Row(
            children: [
              CartPhoto(cart: cart, media: bundle.media, size: 60, radius: 18),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cart.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${cart.locationLabel} · ${cart.followersCount} '
                      '${cart.followersCount == 1 ? 'follower' : 'followers'}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (owner.error case final error?) ...[
            const SizedBox(height: 14),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 18),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Shop is open',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    cart.isOpen
                        ? 'Customers see you as open. Followers were notified.'
                        : 'Customers see your shop as closed.',
                  ),
                  value: cart.isOpen,
                  onChanged: owner.busy ? null : owner.setOpen,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text(
                    'Share live location',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    owner.isBroadcasting
                        ? 'Publishing your position as you move.'
                        : cart.lastLocationAt == null
                            ? 'Off. Your pin stays where you last set it.'
                            : 'Off. Last updated '
                                '${RelativeTime.label(cart.lastLocationAt!)}.',
                  ),
                  value: owner.isBroadcasting,
                  onChanged: (value) => value
                      ? owner.startBroadcast()
                      : owner.stopBroadcast(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CartMap(
                carts: <dynamic>[cart].cast(),
                userLocation: null,
                initialCenter: cart.position,
                showRadius: false,
              ),
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.schedule, color: AppColors.primary),
                  title: const Text(
                    'Hours and next stop',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(cart.scheduleSummary()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ScheduleEditorScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Photos',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    cart.photoRefs.isEmpty
                        ? 'Add menu shots and cart branding'
                        : '${cart.photoRefs.length} uploaded',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showPhotoManager(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.campaign_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Post an update',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Send a message to everyone following you',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showAnnouncementSheet(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Recent activity',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<CartUpdateModel>>(
            stream: bundle.notifications.watchCartUpdates(cart.id),
            builder: (context, snapshot) {
              final updates = snapshot.data ?? const <CartUpdateModel>[];
              if (updates.isEmpty) {
                return Text(
                  'Nothing published yet.',
                  style: TextStyle(color: Colors.grey.shade600),
                );
              }
              return Column(
                children: [
                  for (final update in updates.take(8))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SectionCard(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.history,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(update.message)),
                            Text(
                              RelativeTime.label(update.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showPhotoManager(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (_) => const _PhotoManager(),
    );
  }

  Future<void> _showAnnouncementSheet(BuildContext context) {
    final controller = TextEditingController();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Post an update',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Fresh batch of momos ready at 6pm!',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final text = controller.text;
                  Navigator.of(sheetContext).pop();
                  await context
                      .read<OwnerController>()
                      .publishAnnouncement(text);
                },
                child: const Text('Send to followers'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoManager extends StatelessWidget {
  const _PhotoManager();

  @override
  Widget build(BuildContext context) {
    final owner = context.watch<OwnerController>();
    final media = context.read<RepositoryBundle>().media;
    final cart = owner.cart;
    if (cart == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cart photos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (cart.photoRefs.isEmpty)
            Text(
              'No photos yet. Customers are far more likely to stop at a cart '
              'they can see.',
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            )
          else
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cart.photoRefs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final ref = cart.photoRefs[index];
                  return Stack(
                    children: [
                      CartPhoto(
                        cart: cart,
                        media: media,
                        photoRef: ref,
                        size: 92,
                        radius: 14,
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: InkWell(
                          onTap: () => owner.removePhoto(ref),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: owner.busy
                      ? null
                      : () => _pick(context, ImageSource.gallery),
                  icon: const Icon(Icons.photo_outlined),
                  label: const Text('Gallery'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: owner.busy
                      ? null
                      : () => _pick(context, ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final owner = context.read<OwnerController>();
    // Compressed at pick time rather than after: cheaper, and it keeps the
    // web data-URI path inside its size cap.
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 70,
    );
    if (file == null) return;
    await owner.addPhoto(file);
  }
}
