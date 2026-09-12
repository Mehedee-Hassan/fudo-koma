import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session_controller.dart';
import '../../theme/app_colors.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';

/// Guests can browse the map, search, and open cart details. Following,
/// reporting and alert settings need an identity: a device-scoped follow cannot
/// survive a reinstall and there is nobody to deliver a notification to.
Future<void> showSignInRequired(
  BuildContext context, {
  required String action,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sign in to $action',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Your follows and alerts are tied to your account, so they follow '
            'you to any device.',
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RegisterScreen(),
                  ),
                );
              },
              child: const Text('Create account'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('I already have an account'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// True when the action may proceed; shows the sheet and returns false if not.
Future<bool> ensureSignedIn(
  BuildContext context, {
  required String action,
}) async {
  final session = context.read<SessionController>();
  if (session.canFollow) return true;
  await showSignInRequired(context, action: action);
  return false;
}
