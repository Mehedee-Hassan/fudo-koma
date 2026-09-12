import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_controller.dart';
import '../theme/app_colors.dart';
import 'auth/blocked_screen.dart';
import 'auth/welcome_screen.dart';
import 'shell/app_shell.dart';

/// Single gate for the whole app. Roles change what Profile offers, never which
/// tabs exist - a role-dependent tab index breaks deep links and muscle memory.
class RootRouter extends StatelessWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select<SessionController, AuthStatus>(
      (session) => session.status,
    );

    return switch (status) {
      AuthStatus.unknown => const _StartupScreen(),
      AuthStatus.signedOut => const WelcomeScreen(),
      AuthStatus.blocked => const BlockedScreen(),
      AuthStatus.guest || AuthStatus.authenticated => const AppShell(),
    };
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_rounded, size: 44, color: AppColors.primary),
            SizedBox(height: 18),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
