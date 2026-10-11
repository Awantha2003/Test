import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/providers.dart';
import '../../widgets/common.dart';

const _days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const _dayLabels = {'mon': 'M', 'tue': 'T', 'wed': 'W', 'thu': 'T', 'fri': 'F', 'sat': 'S', 'sun': 'S'};

/// "Nimal should reach Maths class by 3:30 pm on Tue & Thu": late alerts.
class SchedulesScreen extends ConsumerWidget {
  const SchedulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(schedulesProvider);
    final children = ref.watch(childrenProvider).value ?? const <Child>[];
    final places = ref.watch(placesProvider).value ?? const <Place>[];
    final canAdd = children.isNotEmpty && places.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Schedules')),
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(onPressed: () => _edit(context, ref, children, places), icon: const Icon(Icons.add_alarm_rounded), label: const Text('Add schedule'))
          : null,
      body: AsyncView(
        value: schedules,
        builder: (list) {
          if (!canAdd) {
            return const EmptyState(icon: Icons.alarm_add_rounded, title: 'Add a child and a place first', message: 'Schedules need a child and a place, such as a tuition class.');
          }
          if (list.isEmpty) {
            return const EmptyState(icon: Icons.alarm_rounded, title: 'No schedules yet', message: "We'll alert you if your child hasn't reached a class or school by the time you set.");
          }
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
            for (final s in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    onTap: () => _edit(context, ref, children, places, existing: s),
                    leading: const CircleAvatar(child: Icon(Icons.alarm_on_rounded)),
                    title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${children.where((c) => c.id == s.childId).firstOrNull?.name ?? '?'} → '
                      '${places.where((p) => p.id == s.placeId).firstOrNull?.name ?? '?'} by ${s.arriveBy}\n'
                      '${_days.where(s.days.contains).map((d) => d[0].toUpperCase() + d.substring(1)).join(', ')}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => runGuarded(context, () => ref.read(apiProvider).deleteSchedule(s.id), success: 'Schedule removed'),
                    ),
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, List<Child> children, List<Place> places, {Schedule? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ScheduleEditor(children: children, places: places, existing: existing),
    );
  }
}

class _ScheduleEditor extends ConsumerStatefulWidget {
  const _ScheduleEditor({required this.children, required this.places, this.existing});
  final List<Child> children;
  final List<Place> places;
  final Schedule? existing;
  @override
  ConsumerState<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends ConsumerState<_ScheduleEditor> {
  late String _child = widget.existing?.childId ?? widget.children.first.id;
  late String _place = widget.existing?.placeId ?? (widget.places.where((p) => p.type == PlaceType.classroom).firstOrNull ?? widget.places.first).id;
  late final _label = TextEditingController(text: widget.existing?.label ?? '');
  late final Set<String> _selDays = {...?widget.existing?.days};
  late TimeOfDay _time = _parse(widget.existing?.arriveBy ?? '15:00');
  bool _busy = false;

  static TimeOfDay _parse(String s) => TimeOfDay(hour: int.parse(s.split(':')[0]), minute: int.parse(s.split(':')[1]));
  String get _hhmm => '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick at least one day.')));
      return;
    }
    setState(() => _busy = true);
    final placeName = widget.places.firstWhere((p) => p.id == _place).name;
    final ok = await runGuarded(
      context,
      () => ref.read(apiProvider).saveSchedule({
        if (widget.existing != null) 'id': widget.existing!.id,
        'childId': _child,
        'placeId': _place,
        'label': _label.text.trim().isEmpty ? placeName : _label.text.trim(),
        'days': _selDays.toList(),
        'arriveBy': _hhmm,
        'graceMin': 10,
        'tz': 'Asia/Colombo',
        'active': true,
      }),
      success: 'Schedule saved',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok != null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.existing == null ? 'New schedule' : 'Edit schedule', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _child,
          decoration: const InputDecoration(labelText: 'Child'),
          items: [for (final c in widget.children) DropdownMenuItem(value: c.id, child: Text(c.name))],
          onChanged: (v) => setState(() => _child = v!),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _place,
          decoration: const InputDecoration(labelText: 'Should arrive at'),
          items: [for (final p in widget.places) DropdownMenuItem(value: p.id, child: Text(p.name))],
          onChanged: (v) => setState(() => _place = v!),
        ),
        const SizedBox(height: 12),
        TextField(controller: _label, decoration: const InputDecoration(labelText: 'Label (optional)', hintText: 'e.g. Maths tuition')),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final d in _days)
            FilterChip(
              label: Text(_dayLabels[d]!),
              selected: _selDays.contains(d),
              showCheckmark: false,
              onSelected: (v) => setState(() => v ? _selDays.add(d) : _selDays.remove(d)),
            ),
        ]),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule_rounded),
          title: const Text('Arrive by'),
          trailing: Text(_time.format(context), style: Theme.of(context).textTheme.titleMedium),
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: _time);
            if (t != null) setState(() => _time = t);
          },
        ),
        Text("We'll alert you 10 minutes after this time if they haven't arrived.", style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save')),
      ]),
    );
  }
}
