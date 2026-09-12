import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_exception.dart';
import '../../repositories/local/local_seed.dart';
import '../../repositories/repository_bundle.dart';
import '../../state/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final mode = context.read<RepositoryBundle>().mode;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: BackendModeBadge(
                  label: mode.label,
                  isLocal: mode.isLocal,
                ),
              ),
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 22),
              const Text(
                'Follo Cart',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Find street food carts near you, follow the ones you love, '
                'and get an alert when they roll within 5 km.',
                style: TextStyle(color: Colors.grey.shade600, height: 1.5),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: session.busy
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const RegisterScreen(),
                            ),
                          ),
                  child: const Text('Create account'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                  ),
                  child: const Text(
                    'Sign in',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: session.continueAsGuest,
                  child: const Text('Browse as guest'),
                ),
              ),
              if (kDebugMode && mode.isLocal) ...[
                const SizedBox(height: 6),
                const _DemoSignIn(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Debug-only, local-mode-only one-tap sign-in.
///
/// Typing an email and password on a phone to check a fix is friction that
/// discourages testing the signed-in paths at all. Release builds never show
/// this - there is nothing to sign into.
class _DemoSignIn extends StatelessWidget {
  const _DemoSignIn();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, size: 14, color: AppColors.warning),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Demo sign-in (debug builds only)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                LocalSeed.demoPassword,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _RoleButton(
                  label: 'Customer',
                  email: LocalSeed.customerEmail,
                  enabled: !session.busy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RoleButton(
                  label: 'Owner',
                  email: LocalSeed.ownerEmail,
                  enabled: !session.busy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RoleButton(
                  label: 'Admin',
                  email: LocalSeed.adminEmail,
                  enabled: !session.busy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${LocalSeed.customerEmail} · ${LocalSeed.ownerEmail} · '
            '${LocalSeed.adminEmail}',
            style: TextStyle(
              fontSize: 10,
              height: 1.4,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.label,
    required this.email,
    required this.enabled,
  });

  final String label;
  final String email;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: AppColors.border),
      ),
      onPressed: enabled ? () => _signIn(context) : null,
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }

  Future<void> _signIn(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<SessionController>().signIn(
            email: email,
            password: LocalSeed.demoPassword,
          );
    } on AuthException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
