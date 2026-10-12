import 'package:app_control/app_rules.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../widgets/common.dart';

/// Guardian view: what the child uses, for how long, and what's allowed when.
class AppControlsScreen extends ConsumerStatefulWidget {
  const AppControlsScreen({super.key, required this.childId});
  final String childId;
  @override
  ConsumerState<AppControlsScreen> createState() => _AppControlsScreenState();
}

class _AppControlsScreenState extends ConsumerState<AppControlsScreen> {
  String _query = '';

  Future<void> _save(AppRules rules) async {
    final s = ref.read(sessionProvider).value!;
    await runGuarded(
      context,
      () => familyCol(s.familyId!, 'appRules').doc(widget.childId).set({
        ...rules.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': s.uid,
      }),
    );
  }

  /// Schedules always offered: school time and bedtime (+ study time), editable.
  List<TimeWindow> _schedules(AppRules r) {
    final byId = {for (final w in r.schedules) w.id: w};
    return [
      for (final t in const [TimeWindow.schoolTime, TimeWindow.bedtime, TimeWindow.studyTime]) byId[t.id] ?? t.copyWith(active: false),
      ...r.schedules.where((w) => !const {'school', 'bedtime', 'study'}.contains(w.id)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final family = ref.watch(familyProvider).value;
    final child = (ref.watch(childrenProvider).value ?? const <Child>[]).where((c) => c.id == widget.childId).firstOrNull;
    final usage = ref.watch(appUsageProvider(widget.childId));
    final rules = ref.watch(appRulesProvider(widget.childId)).value ?? AppRules.empty;
    final name = child?.name ?? 'your child';

    if (family != null && !family.appControls) {
      return Scaffold(
        appBar: AppBar(title: const Text('App controls')),
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'App controls are on Family and Premium',
          message: 'See which apps $name uses and for how long, block apps, and pause apps during school time and bedtime.',
          action: FilledButton(onPressed: () => context.push('/p/plans'), child: const Text('See plans')),
        ),
      );
    }
    if (child?.platform == 'ios') {
      return Scaffold(
        appBar: AppBar(title: const Text('App controls')),
        body: const EmptyState(
          icon: Icons.phone_iphone_rounded,
          title: 'Android phones only for now',
          message: "On iPhone, use Apple's Screen Time (Settings → Screen Time → Family). Rakawala support for iPhone needs Apple's approval and is on the way.",
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('$name\'s apps')),
      body: AsyncView(
        value: usage,
        builder: (report) {
          if (report == null) return _SetupHint(name: name);
          final today = report.isToday;
          final schedules = _schedules(rules);
          final installed = [...report.installed]..sort((a, b) {
              final ma = today ? (report.apps[a.pkg]?.minutes ?? 0) : 0, mb = today ? (report.apps[b.pkg]?.minutes ?? 0) : 0;
              return mb != ma ? mb.compareTo(ma) : a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
          final visible = installed.where((a) => _query.isEmpty || a.name.toLowerCase().contains(_query.toLowerCase())).toList();
          final total = today ? report.totalMin : 0;

          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
            if (!report.controlsOn)
              Card(
                color: AppColors.warn.withValues(alpha: 0.12),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: AppColors.warn),
                  title: const Text('Controls are off on the phone'),
                  subtitle: Text(
                    !report.usageAccess
                        ? 'Open Rakawala on $name\'s phone → App controls → allow "Usage access".'
                        : 'Open Rakawala on $name\'s phone → App controls → turn on "Rakawala app controls".',
                  ),
                ),
              ),
            // Screen time today
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Screen time today', style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(_hm(total), style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  if (rules.dailyLimitMin > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (total / rules.dailyLimitMin).clamp(0, 1).toDouble(),
                        minHeight: 8,
                        color: total >= rules.dailyLimitMin ? AppColors.sos : AppColors.brand,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Daily limit ${_hm(rules.dailyLimitMin)}', style: t.textTheme.bodySmall),
                  ],
                  const SizedBox(height: 8),
                  Text('Updated ${timeAgo(report.ts)}', style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  const Divider(height: 24),
                  Row(children: [
                    const Expanded(child: Text('Daily screen-time limit')),
                    DropdownButton<int>(
                      value: const [0, 60, 120, 180, 240, 300].contains(rules.dailyLimitMin) ? rules.dailyLimitMin : 0,
                      underline: const SizedBox.shrink(),
                      items: [for (final m in const [0, 60, 120, 180, 240, 300]) DropdownMenuItem(value: m, child: Text(m == 0 ? 'No limit' : _hm(m)))],
                      onChanged: (v) => _save(rules.copyWith(dailyLimitMin: v ?? 0)),
                    ),
                  ]),
                ]),
              ),
            ),
            const SectionHeader('Pause all apps during'),
            Card(
              child: Column(children: [
                for (final w in schedules)
                  SwitchListTile(
                    value: w.active,
                    title: Text(w.label),
                    subtitle: Text('${w.start}–${w.end} · ${_days(w.days)}'),
                    secondary: IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => _editWindow(rules, schedules, w)),
                    onChanged: (v) => _save(rules.copyWith(schedules: [for (final x in schedules) x.id == w.id ? x.copyWith(active: v) : x])),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text('Calls, SMS, Rakawala (SOS) and apps marked "Always allowed" keep working.', style: t.textTheme.bodySmall),
            ),
            SectionHeader('Apps (${installed.length})'),
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search apps'),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            for (final a in visible)
              _AppTile(
                name: a.name,
                minutes: today ? (report.apps[a.pkg]?.minutes ?? 0) : 0,
                maxMinutes: total == 0 ? 1 : (report.apps.values.map((e) => e.minutes).fold<int>(1, (m, v) => v > m ? v : m)),
                rule: rules.ruleFor(a.pkg),
                onTap: () => _editApp(rules, a.pkg, a.name),
              ),
          ]);
        },
      ),
    );
  }

  Future<void> _editApp(AppRules rules, String pkg, String name) async {
    final current = rules.ruleFor(pkg);
    final picked = await showModalBottomSheet<AppRule>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
          _choice(context, current, const AppRule(), Icons.check_circle_outline_rounded, 'Allowed', 'Follows schedules and the daily limit'),
          _choice(context, current, const AppRule(mode: AppMode.always), Icons.verified_rounded, 'Always allowed', 'Even during school time and bedtime'),
          for (final m in const [15, 30, 60, 120])
            _choice(context, current, AppRule(mode: AppMode.limit, limitMin: m), Icons.timer_outlined, '${_hm(m)} a day', 'Paused when the time is used up'),
          _choice(context, current, const AppRule(mode: AppMode.block), Icons.block_rounded, 'Blocked', 'Can\'t be opened', danger: true),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked == null) return;
    await _save(rules.copyWith(apps: {...rules.apps, pkg: picked}));
  }

  Widget _choice(BuildContext ctx, AppRule current, AppRule value, IconData icon, String title, String subtitle, {bool danger = false}) {
    final selected = current.mode == value.mode && (value.mode != AppMode.limit || current.limitMin == value.limitMin);
    final color = danger ? AppColors.sos : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontWeight: selected ? FontWeight.w700 : null)),
      subtitle: Text(subtitle),
      trailing: selected ? const Icon(Icons.check_rounded) : null,
      onTap: () => Navigator.pop(ctx, value),
    );
  }

  Future<void> _editWindow(AppRules rules, List<TimeWindow> all, TimeWindow w) async {
    final edited = await showModalBottomSheet<TimeWindow>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => _WindowEditor(window: w));
    if (edited == null) return;
    await _save(rules.copyWith(schedules: [for (final x in all) x.id == edited.id ? edited : x]));
  }
}

String _hm(int min) => min < 60 ? '$min min' : '${min ~/ 60} h${min % 60 == 0 ? '' : ' ${min % 60} min'}';

String _days(List<String> d) {
  if (d.length == 7) return 'Every day';
  if (d.length == 5 && TimeWindow.weekdays.every(d.contains)) return 'Mon–Fri';
  return TimeWindow.allDays.where(d.contains).map((x) => x[0].toUpperCase() + x.substring(1)).join(', ');
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.name, required this.minutes, required this.maxMinutes, required this.rule, required this.onTap});
  final String name;
  final int minutes;
  final int maxMinutes;
  final AppRule rule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final (label, color) = switch (rule.mode) {
      AppMode.block => ('Blocked', AppColors.sos),
      AppMode.limit => ('${_hm(rule.limitMin)}/day', AppColors.warn),
      AppMode.always => ('Always', AppColors.safe),
      AppMode.allow => ('Allowed', t.colorScheme.onSurfaceVariant),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          ),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: maxMinutes == 0 ? 0 : minutes / maxMinutes, minHeight: 4, color: AppColors.brand.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 2),
            Text(minutes == 0 ? 'Not used today' : '${_hm(minutes)} today', style: t.textTheme.bodySmall),
          ]),
          trailing: Chip(
            label: Text(label),
            labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
            backgroundColor: color.withValues(alpha: 0.1),
            side: BorderSide.none,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

class _WindowEditor extends StatefulWidget {
  const _WindowEditor({required this.window});
  final TimeWindow window;
  @override
  State<_WindowEditor> createState() => _WindowEditorState();
}

class _WindowEditorState extends State<_WindowEditor> {
  late TimeWindow _w = widget.window;

  Future<void> _pick(bool start) async {
    final cur = (start ? _w.start : _w.end).split(':');
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(cur[0]), minute: int.parse(cur[1])));
    if (picked == null) return;
    final v = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() => _w = start ? _w.copyWith(start: v) : _w.copyWith(end: v));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_w.label, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => _pick(true), child: Text('From ${_w.start}'))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton(onPressed: () => _pick(false), child: Text('To ${_w.end}'))),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 6, children: [
              for (final d in TimeWindow.allDays)
                FilterChip(
                  label: Text(d[0].toUpperCase() + d.substring(1, 2)),
                  showCheckmark: false,
                  selected: _w.days.contains(d),
                  onSelected: (v) => setState(() => _w = _w.copyWith(days: v ? [..._w.days, d] : (_w.days.where((x) => x != d).toList()))),
                ),
            ]),
            const SizedBox(height: 16),
            FilledButton(onPressed: _w.days.isEmpty || _w.start == _w.end ? null : () => Navigator.pop(context, _w.copyWith(active: true)), child: const Text('Save')),
          ]),
        ),
      );
}

class _SetupHint extends StatelessWidget {
  const _SetupHint({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.app_settings_alt_rounded,
        title: 'Turn on app controls on $name\'s phone',
        message: 'Open Rakawala on $name\'s Android phone → "App controls" → allow Usage access and turn on "Rakawala app controls". '
            'Do it together, so $name knows what\'s being managed.',
      );
}
