import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../services/routing.dart';
import '../../widgets/common.dart';
import 'map_widgets.dart';

/// "Live track": the guardian's own position, the child moving in real time,
/// the path the child has taken, and the road route between them.
class LiveTrackScreen extends ConsumerStatefulWidget {
  const LiveTrackScreen({super.key, required this.childId});
  final String childId;
  @override
  ConsumerState<LiveTrackScreen> createState() => _LiveTrackScreenState();
}

class _LiveTrackScreenState extends ConsumerState<LiveTrackScreen> {
  static const sessionMinutes = 15;

  final _map = MapController();
  final _routing = Routing();
  late final Api _api = ref.read(apiProvider);

  StreamSubscription<Position>? _meSub;
  LatLng? _me;
  RouteResult? _route;
  LatLng? _routedFrom, _routedTo;
  DateTime _routedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _routing_ = false;

  /// Points received during this session, appended to stored history for a smooth trail.
  final _sessionTrail = <LatLng>[];
  bool _follow = true;
  Timer? _tick;
  String? _liveError;

  @override
  void initState() {
    super.initState();
    _startLive();
    _watchMe();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _meSub?.cancel();
    _tick?.cancel();
    // Save the child's battery as soon as nobody is watching.
    unawaited(_api.setLiveTracking(widget.childId, 0).catchError((_) => null));
    super.dispose();
  }

  Future<void> _startLive() async {
    try {
      await _api.setLiveTracking(widget.childId, sessionMinutes);
      if (mounted) setState(() => _liveError = null);
    } on ApiException catch (e) {
      if (mounted) setState(() => _liveError = e.message);
    }
  }

  Future<void> _watchMe() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      _meSub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)).listen((p) {
        if (!mounted) return;
        setState(() => _me = LatLng(p.latitude, p.longitude));
      });
    } catch (_) {
      // The guardian's own location is optional; the child's position still shows.
    }
  }

  /// Re-route only when someone moved meaningfully or a minute passed (saves data and API calls).
  void _maybeRoute(LatLng child) {
    final me = _me;
    if (me == null || _routing_) return;
    const d = Distance();
    final moved = _routedFrom == null ||
        d.as(LengthUnit.Meter, _routedFrom!, me) > 50 ||
        d.as(LengthUnit.Meter, _routedTo!, child) > 50;
    if (!moved && DateTime.now().difference(_routedAt) < const Duration(minutes: 1)) return;
    _routing_ = true;
    _routing.route(me, child).then((r) {
      if (!mounted) return;
      setState(() {
        _route = r;
        _routedFrom = me;
        _routedTo = child;
        _routedAt = DateTime.now();
      });
    }).whenComplete(() => _routing_ = false);
  }

  void _fitBoth(LatLng child) {
    final pts = [child, ?_me];
    if (pts.length == 1) {
      _map.move(child, 16);
    } else {
      _map.fitCamera(CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.fromLTRB(60, 120, 60, 300)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final child = (ref.watch(childrenProvider).value ?? const <Child>[]).where((c) => c.id == widget.childId).firstOrNull;
    final loc = ref.watch(liveProvider).value?[widget.childId];
    final history = ref.watch(historyProvider(widget.childId)).value ?? const <HistoryPoint>[];

    if (child == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    if (loc == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Live: ${child.name}')),
        body: const EmptyState(icon: Icons.location_searching_rounded, title: 'Waiting for location', message: "As soon as the child's phone reports in, it appears here."),
      );
    }

    final childPos = LatLng(loc.lat, loc.lng);
    if (_sessionTrail.isEmpty || _sessionTrail.last != childPos) {
      _sessionTrail.add(childPos);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _maybeRoute(childPos);
        if (_follow) _map.move(childPos, math.max(_map.camera.zoom, 16));
      });
    }

    final since = DateTime.now().subtract(const Duration(minutes: 30));
    final trail = [
      ...history.where((h) => h.ts != null && h.ts!.isAfter(since)).map((h) => LatLng(h.lat, h.lng)),
      ..._sessionTrail,
    ];
    final age = loc.age ?? Duration.zero;
    final moving = (loc.speed ?? 0) * 3.6 >= 1.5;
    final dir = moving ? compassDirection(loc.heading ?? -1) : '';
    final liveLeft = child.liveUntil?.difference(DateTime.now());
    final isLive = liveLeft != null && !liveLeft.isNegative;
    final distance = _route?.distanceM ?? (_me == null ? null : const Distance().as(LengthUnit.Meter, _me!, childPos));

    return Scaffold(
      body: Stack(children: [
        BaseMap(
          controller: _map,
          center: childPos,
          zoom: 16,
          children: [
            // Road route from me to the child
            if (_route != null && _me != null)
              PolylineLayer(polylines: [
                Polyline(
                  points: _route!.points,
                  strokeWidth: 5,
                  color: AppColors.brand.withValues(alpha: 0.8),
                  pattern: _route!.byRoad ? const StrokePattern.solid() : StrokePattern.dashed(segments: const [12, 8]),
                ),
              ]),
            // Where the child has been (last 30 min)
            if (trail.length > 1) PolylineLayer(polylines: [Polyline(points: trail, strokeWidth: 4, color: child.color.withValues(alpha: 0.55))]),
            ...childLayers([child], {child.id: loc}),
            if (moving && (loc.heading ?? -1) >= 0)
              MarkerLayer(markers: [
                Marker(
                  point: childPos,
                  width: 80,
                  height: 80,
                  child: IgnorePointer(
                    child: Transform.rotate(
                      angle: (loc.heading ?? 0) * math.pi / 180,
                      child: Align(alignment: Alignment.topCenter, child: Icon(Icons.navigation_rounded, color: child.color, size: 22)),
                    ),
                  ),
                ),
              ]),
            if (_me != null)
              MarkerLayer(markers: [
                Marker(
                  point: _me!,
                  width: 26,
                  height: 26,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: const [BoxShadow(color: Color(0x551D4ED8), blurRadius: 12, spreadRadius: 4)],
                    ),
                  ),
                ),
              ]),
          ],
        ),
        // Top bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              IconButton.filledTonal(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)),
              const SizedBox(width: 8),
              Expanded(
                child: Material(
                  color: t.colorScheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      _LiveDot(active: isLive),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isLive
                              ? 'LIVE · ${liveLeft.inMinutes}:${(liveLeft.inSeconds % 60).toString().padLeft(2, '0')} left'
                              : (_liveError ?? 'Live mode off'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isLive || liveLeft.inMinutes < 3) TextButton(onPressed: _startLive, child: Text(isLive ? 'Extend' : 'Start')),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
        // Map controls
        Positioned(
          right: 12,
          bottom: 290,
          child: Column(children: [
            FloatingActionButton.small(
              heroTag: 'follow',
              tooltip: _follow ? 'Following child' : 'Follow child',
              backgroundColor: _follow ? AppColors.brand : null,
              foregroundColor: _follow ? Colors.white : null,
              onPressed: () {
                setState(() => _follow = !_follow);
                if (_follow) _map.move(childPos, 16);
              },
              child: const Icon(Icons.my_location_rounded),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: 'both',
              tooltip: 'Show me and child',
              onPressed: () {
                setState(() => _follow = false);
                _fitBoth(childPos);
              },
              child: const Icon(Icons.zoom_out_map_rounded),
            ),
          ]),
        ),
        // Info panel
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(blurRadius: 20, color: Color(0x22000000))],
            ),
            child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  ChildAvatar(label: child.initials, color: child.color, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(child.name, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        '${movementLabel(loc.speed)}${moving ? ' · ${((loc.speed ?? 0) * 3.6).round()} km/h' : ''}${dir.isNotEmpty ? ' · heading $dir' : ''}',
                        style: t.textTheme.bodyMedium,
                      ),
                    ]),
                  ),
                  BatteryBadge(level: loc.battery, charging: loc.charging),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  _Metric(icon: Icons.straighten_rounded, label: 'From you', value: distance == null ? '—' : formatDistance(distance)),
                  _Metric(
                    icon: Icons.directions_car_rounded,
                    label: _route?.byRoad == true ? 'Drive time' : 'Drive time (est.)',
                    value: _route?.duration != null ? formatEta(_route!.duration!) : (distance == null ? '—' : formatEta(Duration(seconds: (distance / 8.3).round()))),
                  ),
                  _Metric(
                    icon: Icons.update_rounded,
                    label: 'Updated',
                    value: age.inSeconds < 60 ? '${age.inSeconds} s ago' : timeAgo(loc.ts),
                    warn: age > const Duration(minutes: 2),
                  ),
                ]),
                if (_me == null) ...[
                  const SizedBox(height: 8),
                  Text('Turn on your location to see the route from you.', style: t.textTheme.bodySmall),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${loc.lat},${loc.lng}&travelmode=driving'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.navigation_rounded),
                  label: Text('Navigate to ${child.name}'),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value, this.warn = false});
  final IconData icon;
  final String label;
  final String value;
  final bool warn;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = warn ? AppColors.warn : t.colorScheme.onSurface;
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: t.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(child: Text(label, style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 2),
        Text(value, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.active});
  final bool active;
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: widget.active ? Tween(begin: 0.3, end: 1.0).animate(_c) : const AlwaysStoppedAnimation(1),
        child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.active ? AppColors.sos : Colors.grey)),
      );
}
