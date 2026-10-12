import 'package:app_control/app_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';

/// Child phone: explains app controls honestly and walks through the two Android settings.
/// Shown only on Android and only once a guardian has set rules.
class AppControlsCard extends ConsumerStatefulWidget {
  const AppControlsCard({super.key});
  @override
  ConsumerState<AppControlsCard> createState() => _AppControlsCardState();
}

class _AppControlsCardState extends ConsumerState<AppControlsCard> with WidgetsBindingObserver {
  ControlsStatus _status = ControlsStatus.unsupported;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final s = await AppControl.status();
    if (mounted) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    if (!AppControl.supported) return const SizedBox.shrink();
    final uid = ref.watch(sessionProvider).value?.uid;
    if (uid == null) return const SizedBox.shrink();
    final rules = ref.watch(appRulesProvider(uid)).value ?? AppRules.empty;
    final hasRules = rules.apps.isNotEmpty || rules.schedules.any((w) => w.active) || rules.dailyLimitMin > 0;
    if (!hasRules && !_status.ready) return const SizedBox.shrink();
    final t = Theme.of(context);
    final now = DateTime.now();
    final activeWindow = rules.schedules.where((w) => w.isActiveAt(now)).firstOrNull;
    final blockedCount = rules.apps.values.where((r) => r.mode == AppMode.block).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.app_settings_alt_rounded, color: AppColors.brand),
            const SizedBox(width: 8),
            Text('App controls', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (_status.ready) const Chip(label: Text('On'), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 8),
          if (_status.ready) ...[
            Text(activeWindow != null
                ? '${activeWindow.label} until ${activeWindow.end}: most apps are paused.'
                : 'Your family manages app time on this phone.'),
            if (blockedCount > 0) Text('$blockedCount app${blockedCount == 1 ? '' : 's'} blocked.', style: t.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text('Calls, SMS and SOS always work.', style: t.textTheme.bodySmall),
          ] else ...[
            const Text(
              'Your family wants to manage app time on this phone (school time, bedtime and daily limits). '
              'Rakawala only sees which app is open and for how long. It never reads your screen, messages or what you type.',
            ),
            const SizedBox(height: 12),
            _Step(
              done: _status.usageAccess,
              title: '1. Allow "Usage access"',
              onTap: AppControl.openUsageAccessSettings,
            ),
            _Step(
              done: _status.accessibility,
              title: '2. Turn on "Rakawala app controls"',
              subtitle: 'Settings → Accessibility → Installed apps',
              onTap: AppControl.openAccessibilitySettings,
            ),
          ],
        ]),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.done, required this.title, this.subtitle, required this.onTap});
  final bool done;
  final String title;
  final String? subtitle;
  final Future<void> Function() onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: done ? AppColors.safe : null),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: done ? null : FilledButton.tonal(onPressed: onTap, child: const Text('Open')),
      );
}
