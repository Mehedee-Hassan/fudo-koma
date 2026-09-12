import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_exception.dart';
import '../../models/user_role.dart';
import '../../repositories/repository_bundle.dart';
import '../../state/session_controller.dart';
import '../../theme/app_colors.dart';
import '../owner/cart_editor_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _adminCode = TextEditingController();

  UserRole _role = UserRole.customer;
  String? _error;
  bool _submitting = false;

  /// Admin is never self-service. It appears only when the build carries an
  /// ADMIN_CODE, and still requires typing that code.
  List<UserRole> get _selectableRoles => <UserRole>[
        UserRole.customer,
        UserRole.owner,
        if (AppConfig.adminSignupEnabled) UserRole.admin,
      ];

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _adminCode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_role == UserRole.admin &&
        _adminCode.text.trim() != AppConfig.adminCode) {
      setState(() => _error = 'That admin code is not valid.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await context.read<SessionController>().register(
            email: _email.text,
            password: _password.text,
            displayName: _name.text,
            role: _role,
          );
      if (!mounted) return;

      // A new owner has no cart yet, so send them straight to creating one.
      if (_role == UserRole.owner) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const CartEditorScreen(mode: CartEditorMode.create),
          ),
        );
      } else {
        Navigator.of(context).pop();
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocal = context.read<RepositoryBundle>().mode.isLocal;

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            children: [
              const Text(
                'Join Follo Cart',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Pick how you want to use the app. You can browse without an '
                'account, but following carts needs one.',
                style: TextStyle(color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 20),
              _RoleSelector(
                roles: _selectableRoles,
                selected: _role,
                onChanged: (role) => setState(() => _role = role),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Your name'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter your name'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Enter your email';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) => (value == null || value.length < 8)
                    ? 'Use at least 8 characters'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
                validator: (value) => value != _password.text
                    ? 'Passwords do not match'
                    : null,
              ),
              if (_role == UserRole.admin) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _adminCode,
                  decoration: const InputDecoration(labelText: 'Admin code'),
                ),
              ],
              if (isLocal) ...[
                const SizedBox(height: 16),
                const _LocalStorageNotice(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.roles,
    required this.selected,
    required this.onChanged,
  });

  final List<UserRole> roles;
  final UserRole selected;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final role in roles)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onChanged(role),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: role == selected
                        ? AppColors.primary
                        : AppColors.border,
                    width: role == selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      switch (role) {
                        UserRole.customer => Icons.explore_outlined,
                        UserRole.owner => Icons.storefront_outlined,
                        UserRole.admin => Icons.admin_panel_settings_outlined,
                      },
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            role.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            role.blurb,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      role == selected
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: role == selected
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LocalStorageNotice extends StatelessWidget {
  const _LocalStorageNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 17, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Demo account — stored on this device only. Connect Firebase '
              '(see SETUP_FIREBASE.md) for real accounts that sync across '
              'devices.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
