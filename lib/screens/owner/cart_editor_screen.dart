import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/owner_controller.dart';
import '../../state/session_controller.dart';

enum CartEditorMode { create, edit }

class CartEditorScreen extends StatefulWidget {
  const CartEditorScreen({super.key, required this.mode});

  final CartEditorMode mode;

  @override
  State<CartEditorScreen> createState() => _CartEditorScreenState();
}

class _CartEditorScreenState extends State<CartEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _locationLabel;
  late final TextEditingController _description;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final cart = context.read<OwnerController>().cart;
    final isEdit = widget.mode == CartEditorMode.edit && cart != null;

    _name = TextEditingController(text: isEdit ? cart.name : '');
    _category = TextEditingController(text: isEdit ? cart.category : '');
    _locationLabel =
        TextEditingController(text: isEdit ? cart.locationLabel : '');
    _description = TextEditingController(text: isEdit ? cart.description : '');
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _locationLabel.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final owner = context.read<OwnerController>();
    final session = context.read<SessionController>();

    if (widget.mode == CartEditorMode.create) {
      final created = await owner.createCart(
        name: _name.text,
        category: _category.text,
        locationLabel: _locationLabel.text,
        description: _description.text,
      );
      // Link the cart back onto the profile so the owner keeps it after a
      // reinstall even if the cart query changes.
      if (created != null) await session.attachOwnedCart(created.id);
    } else {
      await owner.saveDetails(
        name: _name.text,
        category: _category.text,
        locationLabel: _locationLabel.text,
        description: _description.text,
      );
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    final error = owner.error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.mode == CartEditorMode.create;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCreate ? 'Create your cart' : 'Cart details'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          children: [
            if (isCreate) ...[
              Text(
                'Customers find you by name and category. You can change any '
                'of this later.',
                style: TextStyle(color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 20),
            ],
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Cart name'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Give your cart a name'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                hintText: 'e.g. Nepali street food',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Describe what you serve'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _locationLabel,
              decoration: const InputDecoration(
                labelText: 'Usual spot',
                hintText: 'e.g. Riverside Park',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Where do customers usually find you?'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'About your cart (optional)',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(isCreate ? 'Create cart' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
