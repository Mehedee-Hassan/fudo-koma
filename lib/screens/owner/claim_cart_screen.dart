import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/cart_controller.dart';
import '../../state/owner_controller.dart';
import '../../state/session_controller.dart';
import '../../widgets/common.dart';

/// Debug + local mode only.
///
/// The seeded carts belong to placeholder owner ids, so a demo would otherwise
/// have to drive an empty new cart instead of the one with followers and
/// history. Real ownership transfer needs server-side verification.
class ClaimCartScreen extends StatelessWidget {
  const ClaimCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final carts = context.watch<CartController>().carts;

    return Scaffold(
      appBar: AppBar(title: const Text('Claim a demo cart')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          Text(
            'Debug builds only. Claiming attaches a seeded cart to your '
            'account so you can drive a cart that already has followers.',
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 18),
          for (final cart in carts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SectionCard(
                onTap: () async {
                  final owner = context.read<OwnerController>();
                  final session = context.read<SessionController>();
                  await owner.claimCart(cart.id);
                  await session.attachOwnedCart(cart.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cart.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${cart.category} · ${cart.followersCount} followers',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
