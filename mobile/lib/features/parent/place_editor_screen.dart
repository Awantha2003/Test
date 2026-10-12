import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models.dart';
import '../../data/providers.dart';
import '../../widgets/common.dart';
import 'map_widgets.dart';

class PlaceEditorScreen extends ConsumerStatefulWidget {
  const PlaceEditorScreen({super.key, this.place});
  final Place? place;
  @override
  ConsumerState<PlaceEditorScreen> createState() => _PlaceEditorScreenState();
}

class _PlaceEditorScreenState extends ConsumerState<PlaceEditorScreen> {
  final _map = MapController();
  late final _name = TextEditingController(text: widget.place?.name ?? '');
  late PlaceType _type = widget.place?.type ?? PlaceType.school;
  late double _radius = (widget.place?.radius ?? 150).toDouble();
  late bool _enter = widget.place?.notifyEnter ?? true;
  late bool _exit = widget.place?.notifyExit ?? true;
  late LatLng _center = widget.place != null ? LatLng(widget.place!.lat, widget.place!.lng) : defaultCenter;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.place == null) _useMyLocation(silent: true);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation({bool silent = false}) async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(timeLimit: Duration(seconds: 8)));
      setState(() => _center = LatLng(p.latitude, p.longitude));
      _map.move(_center, 16);
    } catch (_) {
      if (!silent && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't get your location.")));
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give the place a name.')));
      return;
    }
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => ref.read(apiProvider).savePlace({
        if (widget.place != null) 'id': widget.place!.id,
        'name': _name.text.trim(),
        'type': _type.wire,
        'lat': _center.latitude,
        'lng': _center.longitude,
        'radius': _radius.round(),
        'notifyEnter': _enter,
        'notifyExit': _exit,
      }),
      success: 'Place saved',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok != null) context.pop();
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${widget.place!.name}?'),
        content: const Text('Schedules for this place will also be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await runGuarded(context, () => ref.read(apiProvider).deletePlace(widget.place!.id));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.place == null ? 'New place' : 'Edit place'),
        actions: [if (widget.place != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded))],
      ),
      body: Column(children: [
        SizedBox(
          height: 300,
          child: Stack(children: [
            BaseMap(
              controller: _map,
              center: _center,
              zoom: 16,
              onTap: (_, p) => setState(() => _center = p),
              children: [
                CircleLayer(circles: [
                  CircleMarker(point: _center, radius: _radius, useRadiusInMeter: true, color: t.colorScheme.primary.withValues(alpha: 0.18), borderColor: t.colorScheme.primary, borderStrokeWidth: 2),
                ]),
                MarkerLayer(markers: [Marker(point: _center, width: 40, height: 40, child: Icon(Icons.location_on, size: 40, color: t.colorScheme.primary))]),
              ],
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.small(heroTag: 'me', onPressed: _useMyLocation, child: const Icon(Icons.my_location_rounded)),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Text('Tap the map to move the pin', style: t.textTheme.bodySmall))),
            ),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Royal College, Sir\'s Maths class')),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final ty in PlaceType.values)
                ChoiceChip(avatar: Icon(ty.icon, size: 18), label: Text(ty.label), selected: _type == ty, onSelected: (_) => setState(() => _type = ty)),
            ]),
            const SizedBox(height: 16),
            Text('Area size: ${_radius.round()} m', style: t.textTheme.titleSmall),
            Slider(value: _radius, min: 50, max: 1000, divisions: 19, label: '${_radius.round()} m', onChanged: (v) => setState(() => _radius = v)),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: _enter, onChanged: (v) => setState(() => _enter = v), title: const Text('Alert when they arrive')),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: _exit, onChanged: (v) => setState(() => _exit = v), title: const Text('Alert when they leave')),
            const SizedBox(height: 12),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save place')),
          ]),
        ),
      ]),
    );
  }
}
