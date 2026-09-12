import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/id_generator.dart';
import '../../models/schedule_entry_model.dart';
import '../../state/cart_controller.dart';
import '../../state/owner_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/cart_map.dart';

class ScheduleEditorScreen extends StatefulWidget {
  const ScheduleEditorScreen({super.key});

  @override
  State<ScheduleEditorScreen> createState() => _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState extends State<ScheduleEditorScreen> {
  late List<ScheduleEntry> _entries;
  bool _saving = false;

  static const Map<int, String> _dayNames = <int, String>{
    DateTime.monday: 'Monday',
    DateTime.tuesday: 'Tuesday',
    DateTime.wednesday: 'Wednesday',
    DateTime.thursday: 'Thursday',
    DateTime.friday: 'Friday',
    DateTime.saturday: 'Saturday',
    DateTime.sunday: 'Sunday',
  };

  @override
  void initState() {
    super.initState();
    _entries = List<ScheduleEntry>.from(
      context.read<OwnerController>().cart?.scheduleEntries ??
          const <ScheduleEntry>[],
    );
  }

  ScheduleEntry? _weekly(int weekday) {
    for (final entry in _entries) {
      if (!entry.isOneOff && entry.weekday == weekday) return entry;
    }
    return null;
  }

  ScheduleEntry? get _nextStop {
    final oneOffs = _entries.where((e) => e.isOneOff).toList()
      ..sort((a, b) => a.specificDate!.compareTo(b.specificDate!));
    return oneOffs.isEmpty ? null : oneOffs.first;
  }

  Future<void> _pickTime(int weekday, {required bool isOpen}) async {
    final existing = _weekly(weekday);
    final current = existing == null
        ? const TimeOfDay(hour: 11, minute: 30)
        : TimeOfDay(
            hour: (isOpen ? existing.openMinute : existing.closeMinute) ~/ 60,
            minute: (isOpen ? existing.openMinute : existing.closeMinute) % 60,
          );

    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;

    setState(() {
      final base = existing ??
          ScheduleEntry(
            id: newId('sched'),
            weekday: weekday,
            openMinute: 11 * 60 + 30,
            closeMinute: 21 * 60 + 30,
            locationLabel:
                context.read<OwnerController>().cart?.locationLabel ?? '',
          );
      final updated = isOpen
          ? base.copyWith(openMinute: minutes, isActive: true)
          : base.copyWith(closeMinute: minutes, isActive: true);

      _entries
        ..removeWhere((e) => !e.isOneOff && e.weekday == weekday)
        ..add(updated);
    });
  }

  void _toggleDay(int weekday, bool active) {
    setState(() {
      final existing = _weekly(weekday);
      if (existing == null) {
        if (!active) return;
        _entries.add(ScheduleEntry(
          id: newId('sched'),
          weekday: weekday,
          openMinute: 11 * 60 + 30,
          closeMinute: 21 * 60 + 30,
          locationLabel:
              context.read<OwnerController>().cart?.locationLabel ?? '',
        ));
        return;
      }
      _entries
        ..removeWhere((e) => !e.isOneOff && e.weekday == weekday)
        ..add(existing.copyWith(isActive: active));
    });
  }

  Future<void> _editNextStop() async {
    final result = await Navigator.of(context).push<ScheduleEntry>(
      MaterialPageRoute<ScheduleEntry>(
        builder: (_) => _NextStopScreen(existing: _nextStop),
      ),
    );
    if (result == null) return;
    setState(() {
      _entries
        ..removeWhere((e) => e.isOneOff)
        ..add(result);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<OwnerController>().saveSchedule(_entries);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Schedule published to your followers.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextStop = _nextStop;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          Text(
            'Saving publishes a schedule update to everyone following your '
            'cart.',
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 18),
          for (var weekday = DateTime.monday;
              weekday <= DateTime.sunday;
              weekday++)
            _DayRow(
              name: _dayNames[weekday]!,
              entry: _weekly(weekday),
              onToggle: (active) => _toggleDay(weekday, active),
              onPickOpen: () => _pickTime(weekday, isOpen: true),
              onPickClose: () => _pickTime(weekday, isOpen: false),
            ),
          const SizedBox(height: 20),
          const Text(
            'Next stop',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flag_outlined, color: AppColors.primary),
            title: Text(
              nextStop == null
                  ? 'Publish a one-off stop'
                  : nextStop.locationLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              nextStop == null
                  ? 'Tell followers where you will be next.'
                  : '${nextStop.specificDate!.day}/'
                      '${nextStop.specificDate!.month} · '
                      '${nextStop.timeLabel()}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _editNextStop,
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.name,
    required this.entry,
    required this.onToggle,
    required this.onPickOpen,
    required this.onPickClose,
  });

  final String name;
  final ScheduleEntry? entry;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickOpen;
  final VoidCallback onPickClose;

  @override
  Widget build(BuildContext context) {
    final active = entry?.isActive ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Switch(value: active, onChanged: onToggle),
          const SizedBox(width: 4),
          if (active && entry != null)
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: onPickOpen,
                      child: Text(entry!.timeLabel().split(' – ').first),
                    ),
                  ),
                  const Text('–'),
                  Expanded(
                    child: TextButton(
                      onPressed: onPickClose,
                      child: Text(entry!.timeLabel().split(' – ').last),
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Text(
                'Closed',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }
}

class _NextStopScreen extends StatefulWidget {
  const _NextStopScreen({this.existing});

  final ScheduleEntry? existing;

  @override
  State<_NextStopScreen> createState() => _NextStopScreenState();
}

class _NextStopScreenState extends State<_NextStopScreen> {
  late final TextEditingController _label =
      TextEditingController(text: widget.existing?.locationLabel ?? '');
  late DateTime _date =
      widget.existing?.specificDate ?? DateTime.now().add(const Duration(days: 1));
  late TimeOfDay _open = TimeOfDay(
    hour: (widget.existing?.openMinute ?? 720) ~/ 60,
    minute: (widget.existing?.openMinute ?? 720) % 60,
  );
  late TimeOfDay _close = TimeOfDay(
    hour: (widget.existing?.closeMinute ?? 1080) ~/ 60,
    minute: (widget.existing?.closeMinute ?? 1080) % 60,
  );
  LatLng? _picked;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reuses the one map implementation in pick mode rather than building a
    // second, divergent map widget.
    final carts = context.watch<CartController>().carts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Next stop'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(ScheduleEntry(
                id: widget.existing?.id ?? newId('sched'),
                weekday: _date.weekday,
                openMinute: _open.hour * 60 + _open.minute,
                closeMinute: _close.hour * 60 + _close.minute,
                locationLabel: _label.text.trim(),
                latitude: _picked?.latitude,
                longitude: _picked?.longitude,
                specificDate: _date,
              ));
            },
            child: const Text('Done'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  controller: _label,
                  decoration: const InputDecoration(
                    labelText: 'Where',
                    hintText: 'e.g. Oak Street',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 60)),
                          );
                          if (picked != null) setState(() => _date = picked);
                        },
                        child: Text('${_date.day}/${_date.month}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _open,
                          );
                          if (picked != null) setState(() => _open = picked);
                        },
                        child: Text(_open.format(context)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _close,
                          );
                          if (picked != null) setState(() => _close = picked);
                        },
                        child: Text(_close.format(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _picked == null
                      ? 'Tap the map to drop an exact pin (optional).'
                      : 'Pin set. Tap again to move it.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: CartMap(
              carts: carts,
              userLocation: null,
              showRadius: false,
              pickedPoint: _picked,
              onMapTap: (point) => setState(() => _picked = point),
            ),
          ),
        ],
      ),
    );
  }
}
