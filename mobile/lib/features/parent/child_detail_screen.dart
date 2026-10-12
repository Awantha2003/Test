import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models.dart';
import '../../data/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/offline_window_sheet.dart';
import 'map_widgets.dart';

class ChildDetailScreen extends ConsumerStatefulWidget {
  const ChildDetailScreen({super.key, required this.childId});
  final String childId;
  @override
  ConsumerState<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends ConsumerState<ChildDetailScreen> {
  final _map = MapController();
  final _safeWord = TextEditingController();
  bool _safeWordLoaded = false;

  @override
  void dispose() {
    _safeWord.dispose();
    super.dispose();
  }

  Future<void> _saveSettings(Child c, ChildSettings s) async {
    final fid = ref.read(sessionProvider).value!.familyId!;
    await runGuarded(
      context,
      () => familyCol(fid, 'children').doc(c.id).update({'name': c.name, 'color': '#${c.color.toARGB32().toRadixString(16).substring(2).toUpperCase()}', 'settings': s.toMap(), 'updatedAt': FieldValue.serverTimestamp()}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final child = (ref.watch(childrenProvider).value ?? const <Child>[]).where((c) => c.id == widget.childId).firstOrNull;
    final loc = ref.watch(liveProvider).value?[widget.childId];
    final trail = ref.watch(historyProvider(widget.childId)).value ?? const <HistoryPoint>[];
    final family = ref.watch(familyProvider).value;

    if (child == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    if (!_safeWordLoaded) {
      _safeWord.text = child.settings.safeWord;
      _safeWordLoaded = true;
    }
    final s = child.settings;
    final points = trail.map((h) => LatLng(h.lat, h.lng)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(child.name)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 260,
            child: BaseMap(
              controller: _map,
              center: loc != null ? LatLng(loc.lat, loc.lng) : (points.isNotEmpty ? points.last : defaultCenter),
              zoom: 14,
              children: [
                if (points.length > 1) PolylineLayer(polylines: [Polyline(points: points, strokeWidth: 4, color: child.color.withValues(alpha: 0.7))]),
                if (loc != null) ...childLayers([child], {child.id: loc}),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          loc == null ? 'No location yet' : 'Updated ${timeAgo(loc.ts)} · accuracy ±${loc.accuracy.round()} m · trail: last 24 h (${trail.length} points)',
          style: t.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: loc == null ? null : () => context.push('/p/live/${child.id}'),
          icon: const Icon(Icons.radar_rounded),
          label: const Text('Live track (updates every 5 s)'),
        ),
        const SectionHeader('Safety settings'),
        Card(
          child: Column(children: [
            SwitchListTile(
              value: s.guardMode,
              title: const Text('Offline alerts'),
              subtitle: Text('Alert me if the phone stops sharing for ${s.offlineAlertMin} min'),
              onChanged: (v) => _saveSettings(child, s.copyWith(guardMode: v)),
            ),
            ListTile(
              title: const Text('Speed alert'),
              subtitle: Text('Above ${s.speedLimitKmh} km/h'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final v = await _pickNumber(context, 'Speed alert (km/h)', s.speedLimitKmh, [40, 50, 60, 70, 80, 100, 120]);
                if (v != null) await _saveSettings(child, s.copyWith(speedLimitKmh: v));
              },
            ),
            ListTile(
              title: const Text('Low battery alert'),
              subtitle: Text('At ${s.lowBatteryPct}%'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final v = await _pickNumber(context, 'Low battery alert (%)', s.lowBatteryPct, [10, 15, 20, 30]);
                if (v != null) await _saveSettings(child, s.copyWith(lowBatteryPct: v));
              },
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.signal_cellular_off_rounded),
            title: const Text('No signal expected'),
            subtitle: Text('Pause offline alerts during a trip or train ride. The route syncs when ${child.name}\'s phone reconnects.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final w = await showOfflineWindowSheet(context, title: 'Pause offline alerts for ${child.name}', showEnd: true);
              if (w == null || !context.mounted) return;
              await runGuarded(
                context,
                () => ref.read(apiProvider).setOfflineWindow(childId: child.id, minutes: w.minutes, reason: w.reason),
                success: w.minutes == 0 ? 'Offline alerts are back on.' : 'Offline alerts paused for ${durationLabel(w.minutes)}.',
              );
            },
          ),
        ),
        const SectionHeader('Voice SOS'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!(family?.voiceSos ?? false))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: const Text('Available on Family and Premium'),
                  trailing: TextButton(onPressed: () => context.push('/p/plans'), child: const Text('Upgrade')),
                )
              else ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: s.voiceSos,
                  title: const Text('Enable voice SOS'),
                  subtitle: const Text('Your child says a secret word to send SOS hands-free.'),
                  onChanged: (v) => _saveSettings(child, s.copyWith(voiceSos: v)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _safeWord,
                  decoration: InputDecoration(
                    labelText: 'Secret word',
                    helperText: 'Pick an unusual word or phrase, e.g. "purple mango"',
                    suffixIcon: IconButton(icon: const Icon(Icons.save_rounded), onPressed: () => _saveSettings(child, s.copyWith(safeWord: _safeWord.text.trim()))),
                  ),
                ),
              ],
            ]),
          ),
        ),
        const SectionHeader('Device'),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.phone_android_rounded),
              title: Text(child.deviceName ?? 'Not connected'),
              subtitle: Text(child.paired ? 'Connected (${child.platform ?? ''})' : 'Use Re-connect to pair a phone'),
            ),
            ListTile(
              leading: const Icon(Icons.sync_rounded),
              title: const Text('Re-connect / new phone'),
              subtitle: const Text('The old phone will stop sharing.'),
              onTap: () async {
                final r = await runGuarded(context, () => ref.read(apiProvider).createChildCode(child.name, childId: child.id));
                if (r != null && context.mounted) {
                  await showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Code for the new phone'),
                      content: SelectableText(r.code, style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 4), textAlign: TextAlign.center),
                      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_forever_rounded, color: t.colorScheme.error),
              title: Text('Remove ${child.name}', style: TextStyle(color: t.colorScheme.error)),
              subtitle: const Text('Deletes all location history for this child.'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('Remove ${child.name}?'),
                    content: const Text('Their phone will stop sharing and all their location history will be deleted. This cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      FilledButton(style: FilledButton.styleFrom(backgroundColor: t.colorScheme.error), onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  final done = await runGuarded(context, () => ref.read(apiProvider).removeChild(child.id).then((_) => true));
                  if (done == true && context.mounted) context.pop();
                }
              },
            ),
          ]),
        ),
      ]),
    );
  }

  Future<int?> _pickNumber(BuildContext context, String title, int current, List<int> options) => showDialog<int>(
        context: context,
        builder: (_) => SimpleDialog(title: Text(title), children: [
          for (final o in options)
            ListTile(
              title: Text('$o'),
              leading: Icon(o == current ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
              onTap: () => Navigator.pop(context, o),
            ),
        ]),
      );
}
