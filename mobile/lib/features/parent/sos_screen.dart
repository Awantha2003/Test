import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../services/sos_service.dart';
import '../../widgets/common.dart';
import 'map_widgets.dart';

/// Full-screen SOS response: where is my child right now, and what can I do.
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key, required this.alertId});
  final String alertId;
  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  final _map = MapController();

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(alertsProvider).value ?? const <AlertItem>[];
    final alert = alerts.where((a) => a.id == widget.alertId).firstOrNull;
    final children = ref.watch(childrenProvider).value ?? const <Child>[];
    final live = ref.watch(liveProvider).value ?? const <String, LiveLocation>{};
    final members = ref.watch(membersProvider).value ?? const <Member>[];

    if (alert == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final child = children.where((c) => c.id == alert.childId).firstOrNull;
    final loc = live[alert.childId];
    // Prefer the live position (it keeps updating) over the position at SOS time.
    final point = loc != null ? LatLng(loc.lat, loc.lng) : (alert.lat != null ? LatLng(alert.lat!, alert.lng!) : defaultCenter);
    final childPhone = members.where((m) => m.uid == alert.childId).firstOrNull?.phone;
    final open = alert.isOpenSos;

    return Scaffold(
      backgroundColor: open ? AppColors.sos : null,
      appBar: AppBar(
        backgroundColor: open ? AppColors.sos : null,
        foregroundColor: open ? Colors.white : null,
        title: Text(open ? 'SOS: ${alert.childName}' : 'SOS (resolved)'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            '${alert.body}\nSent ${timeAgo(alert.createdAt)} · location updated ${timeAgo(loc?.ts)}',
            style: TextStyle(color: open ? Colors.white : null),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BaseMap(
              controller: _map,
              center: point,
              zoom: 16,
              children: [
                if (child != null) ...childLayers([child], live),
                if (loc == null && alert.lat != null)
                  MarkerLayer(markers: [Marker(point: point, child: const Icon(Icons.location_on, color: AppColors.sos, size: 40))]),
              ],
            ),
          ),
        ),
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SafeArea(
            top: false,
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${point.latitude},${point.longitude}'), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.directions_rounded),
                    label: const Text('Directions'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.sos),
                    onPressed: () => SosService.call(AppConfig.policeEmergency),
                    icon: const Icon(Icons.local_police_rounded),
                    label: const Text('Call 119'),
                  ),
                ),
              ]),
              if (childPhone != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: () => SosService.call(childPhone), icon: const Icon(Icons.call_rounded), label: Text('Call ${alert.childName}')),
              ],
              if (open) ...[
                const SizedBox(height: 10),
                Row(children: [
                  if (alert.status == 'open')
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => runGuarded(context, () => ref.read(apiProvider).resolveAlert(alert.id, status: 'acknowledged'), success: "Other guardians will see you're on it."),
                        child: const Text("I'm on it"),
                      ),
                    ),
                  if (alert.status == 'open') const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Mark as safe?'),
                            content: Text('Only do this once you have confirmed ${alert.childName} is safe.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('They are safe')),
                            ],
                          ),
                        );
                        if (ok == true && context.mounted) {
                          await runGuarded(context, () => ref.read(apiProvider).resolveAlert(alert.id), success: 'SOS resolved');
                        }
                      },
                      child: const Text('Resolved'),
                    ),
                  ),
                ]),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}
