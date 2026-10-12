import 'package:flutter/material.dart';

/// Result of the "no signal ahead" sheet. minutes == 0 means "end the pause now".
typedef OfflineWindow = ({int minutes, String? reason});

const offlineReasons = ['Train', 'Bus', 'Trip', 'Exam', 'Rural area'];
const offlineDurations = [30, 60, 120, 240, 480];

String durationLabel(int m) => m < 60 ? '$m min' : '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60} min'}';

/// Lets a child (or guardian) say "no signal expected for a while", so guardians
/// aren't alarmed by an offline alert during a train ride or rural trip.
Future<OfflineWindow?> showOfflineWindowSheet(BuildContext context, {required String title, bool showEnd = false}) {
  return showModalBottomSheet<OfflineWindow>(
    context: context,
    showDragHandle: true,
    builder: (_) => _OfflineWindowSheet(title: title, showEnd: showEnd),
  );
}

class _OfflineWindowSheet extends StatefulWidget {
  const _OfflineWindowSheet({required this.title, required this.showEnd});
  final String title;
  final bool showEnd;
  @override
  State<_OfflineWindowSheet> createState() => _OfflineWindowSheetState();
}

class _OfflineWindowSheetState extends State<_OfflineWindowSheet> {
  int _minutes = 120;
  String? _reason;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.title, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Your family is told, and "phone stopped sharing" alerts pause until then. '
            'Locations are still saved on the phone and upload when signal returns. SOS still works by SMS.',
            style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text('Why?', style: t.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in offlineReasons)
              ChoiceChip(label: Text(r), selected: _reason == r, onSelected: (v) => setState(() => _reason = v ? r : null)),
          ]),
          const SizedBox(height: 16),
          Text('For how long?', style: t.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in offlineDurations)
              ChoiceChip(label: Text(durationLabel(m)), selected: _minutes == m, onSelected: (_) => setState(() => _minutes = m)),
          ]),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, (minutes: _minutes, reason: _reason)),
            icon: const Icon(Icons.signal_cellular_off_rounded),
            label: Text('Pause alerts for ${durationLabel(_minutes)}'),
          ),
          if (widget.showEnd) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(context, (minutes: 0, reason: null)), child: const Text('End pause now')),
          ],
        ]),
      ),
    );
  }
}
