import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/report_model.dart';
import '../../state/moderation_controller.dart';
import '../../state/session_controller.dart';
import '../../theme/app_colors.dart';

/// The entry point the moderation queue was missing. Without somewhere for
/// customers to file a report, the admin console could only ever be a mock-up.
Future<void> showReportSheet(
  BuildContext context, {
  required ReportTargetType targetType,
  required String targetId,
  required String targetName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    builder: (_) => _ReportSheet(
      targetType: targetType,
      targetId: targetId,
      targetName: targetName,
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.targetType,
    required this.targetId,
    required this.targetName,
  });

  final ReportTargetType targetType;
  final String targetId;
  final String targetName;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason _reason = ReportReason.spam;
  final TextEditingController _note = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = context.read<SessionController>();
    final profile = session.profile;
    if (profile == null) return;

    setState(() => _submitting = true);
    await context.read<ModerationController>().submitReport(
          targetType: widget.targetType,
          targetId: widget.targetId,
          targetName: widget.targetName,
          reporterId: profile.id,
          reporterName: profile.name,
          reason: _reason,
          note: _note.text.trim(),
        );

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks — our team will review this.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report ${widget.targetName}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Tell us what is wrong. Reports go to the moderation queue.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reason in ReportReason.values)
                ChoiceChip(
                  label: Text(reason.label),
                  selected: _reason == reason,
                  onSelected: (_) => setState(() => _reason = reason),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Add a note (optional)',
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: const Text('Submit report'),
            ),
          ),
        ],
      ),
    );
  }
}
