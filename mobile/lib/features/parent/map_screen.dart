import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../widgets/common.dart';
import 'map_widgets.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _map = MapController();
  String? _selected;
  bool _centered = false;

  void _focus(Child c, LiveLocation? loc) {
    setState(() => _selected = c.id);
    if (loc != null) _map.move(LatLng(loc.lat, loc.lng), 16);
  }

  void _fitAll(Map<String, LiveLocation> live) {
    if (live.isEmpty) return;
    if (live.length == 1) {
      final l = live.values.first;
      _map.move(LatLng(l.lat, l.lng), 15);
      return;
    }
    _map.fitCamera(CameraFit.coordinates(coordinates: live.values.map((l) => LatLng(l.lat, l.lng)).toList(), padding: const EdgeInsets.all(80)));
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenProvider).value ?? const <Child>[];
    final live = ref.watch(liveProvider).value ?? const <String, LiveLocation>{};
    final places = ref.watch(placesProvider).value ?? const <Place>[];
    final t = Theme.of(context);

    if (!_centered && live.isNotEmpty) {
      _centered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll(live));
    }

    return Scaffold(
      body: Stack(children: [
        BaseMap(
          controller: _map,
          center: live.isNotEmpty ? LatLng(live.values.first.lat, live.values.first.lng) : defaultCenter,
          children: [
            placesLayer(places, t.colorScheme.primary),
            placeIconsLayer(places, t.colorScheme.primary),
            ...childLayers(children, live, highlight: _selected, onTap: (c) => _focus(c, live[c.id])),
          ],
        ),
        Positioned(
          right: 16,
          top: MediaQuery.paddingOf(context).top + 12,
          child: FloatingActionButton.small(heroTag: 'fit', onPressed: () => _fitAll(live), child: const Icon(Icons.center_focus_strong_rounded)),
        ),
        DraggableScrollableSheet(
          initialChildSize: children.isEmpty ? 0.3 : 0.28,
          minChildSize: 0.12,
          maxChildSize: 0.7,
          builder: (context, scroll) => Container(
            decoration: BoxDecoration(
              color: t.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: const [BoxShadow(blurRadius: 16, color: Color(0x22000000))],
            ),
            child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: t.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 12),
              if (children.isEmpty)
                EmptyState(
                  icon: Icons.child_care_rounded,
                  title: 'Add your first child',
                  message: "Install Rakawala on your child's phone and connect it with a code.",
                  action: FilledButton.icon(onPressed: () => context.go('/p/family'), icon: const Icon(Icons.add), label: const Text('Add child')),
                )
              else
                for (final c in children) _ChildCard(child: c, loc: live[c.id], places: places, selected: _selected == c.id, onTap: () => _focus(c, live[c.id])),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child, required this.loc, required this.places, required this.selected, required this.onTap});
  final Child child;
  final LiveLocation? loc;
  final List<Place> places;
  final bool selected;
  final VoidCallback onTap;

  String _where() {
    if (loc == null) return child.paired ? 'Waiting for first location…' : 'Phone not connected';
    const d = Distance();
    for (final p in places) {
      if (d.as(LengthUnit.Meter, LatLng(p.lat, p.lng), LatLng(loc!.lat, loc!.lng)) <= p.radius) return 'At ${p.name}';
    }
    final kmh = (loc!.speed ?? 0) * 3.6;
    return kmh > 8 ? 'Moving · ${kmh.round()} km/h' : 'Out and about';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final stale = loc?.isStale ?? true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? child.color : t.colorScheme.outlineVariant.withValues(alpha: 0.5), width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              ChildAvatar(label: child.initials, color: child.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(child.name, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(_where(), style: t.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.schedule_rounded, size: 14, color: stale ? AppColors.warn : t.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(timeAgo(loc?.ts), style: t.textTheme.bodySmall?.copyWith(color: stale ? AppColors.warn : t.colorScheme.onSurfaceVariant)),
                    const SizedBox(width: 12),
                    BatteryBadge(level: loc?.battery, charging: loc?.charging ?? false),
                  ]),
                ]),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                IconButton.filledTonal(
                  tooltip: 'Live track',
                  icon: const Icon(Icons.radar_rounded),
                  onPressed: loc == null ? null : () => context.push('/p/live/${child.id}'),
                ),
                IconButton(tooltip: 'Details', icon: const Icon(Icons.chevron_right_rounded), onPressed: () => context.push('/p/child/${child.id}')),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
