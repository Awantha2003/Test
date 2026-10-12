import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

/// Shared base map: configurable tile server + attribution.
class BaseMap extends StatelessWidget {
  const BaseMap({super.key, required this.controller, required this.center, this.zoom = 14, this.children = const [], this.onTap});
  final MapController controller;
  final LatLng center;
  final double zoom;
  final List<Widget> children;
  final void Function(TapPosition, LatLng)? onTap;

  @override
  Widget build(BuildContext context) => FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: center,
          initialZoom: zoom,
          onTap: onTap,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        ),
        children: [
          TileLayer(urlTemplate: AppConfig.mapTileUrl, userAgentPackageName: 'lk.rakawala.rakawala', maxZoom: 19),
          ...children,
          const SimpleAttributionWidget(source: Text(AppConfig.mapAttribution)),
        ],
      );
}

/// Colombo, as a sensible default before any location arrives.
const defaultCenter = LatLng(6.9271, 79.8612);

CircleLayer placesLayer(List<Place> places, Color color) => CircleLayer(circles: [
      for (final p in places)
        CircleMarker(
          point: LatLng(p.lat, p.lng),
          radius: p.radius.toDouble(),
          useRadiusInMeter: true,
          color: color.withValues(alpha: 0.12),
          borderColor: color.withValues(alpha: 0.6),
          borderStrokeWidth: 2,
        ),
    ]);

MarkerLayer placeIconsLayer(List<Place> places, Color color) => MarkerLayer(markers: [
      for (final p in places)
        Marker(
          point: LatLng(p.lat, p.lng),
          width: 34,
          height: 34,
          child: Container(
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
            child: Icon(p.type.icon, size: 18, color: color),
          ),
        ),
    ]);

List<Widget> childLayers(List<Child> children, Map<String, LiveLocation> live, {String? highlight, void Function(Child)? onTap}) {
  final withLoc = children.where((c) => live.containsKey(c.id)).toList();
  return [
    CircleLayer(circles: [
      for (final c in withLoc)
        CircleMarker(
          point: LatLng(live[c.id]!.lat, live[c.id]!.lng),
          radius: live[c.id]!.accuracy.clamp(5, 500).toDouble(),
          useRadiusInMeter: true,
          color: c.color.withValues(alpha: 0.12),
          borderColor: c.color.withValues(alpha: 0.3),
          borderStrokeWidth: 1,
        ),
    ]),
    MarkerLayer(markers: [
      for (final c in withLoc)
        Marker(
          point: LatLng(live[c.id]!.lat, live[c.id]!.lng),
          width: 56,
          height: 56,
          child: GestureDetector(
            onTap: onTap == null ? null : () => onTap(c),
            child: Opacity(
              opacity: live[c.id]!.isStale ? 0.55 : 1,
              child: ChildAvatar(label: c.initials, color: c.color, size: highlight == c.id ? 56 : 48),
            ),
          ),
        ),
    ]),
  ];
}
