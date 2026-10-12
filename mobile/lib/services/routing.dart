import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/config.dart';

class RouteResult {
  RouteResult({required this.points, required this.distanceM, this.duration, required this.byRoad});
  final List<LatLng> points;
  final double distanceM;
  final Duration? duration;

  /// False when we fell back to a straight line (no routing server or no signal).
  final bool byRoad;
}

/// Road route from the guardian to the child (OSRM-compatible API), with a
/// straight-line fallback so the screen always shows something useful.
class Routing {
  Routing({http.Client? client, this.baseUrl = AppConfig.routingUrl}) : _client = client ?? http.Client();
  final http.Client _client;
  final String baseUrl;

  Future<RouteResult> route(LatLng from, LatLng to) async {
    final straight = RouteResult(points: [from, to], distanceM: const Distance().as(LengthUnit.Meter, from, to), byRoad: false);
    if (baseUrl.isEmpty) return straight;
    try {
      final uri = Uri.parse(
        '$baseUrl/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await _client.get(uri, headers: {'User-Agent': 'Rakawala/1.0 (child-safety app)'}).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return straight;
      return parseOsrm(res.body) ?? straight;
    } catch (_) {
      return straight;
    }
  }

  /// Parses an OSRM `route` response with GeoJSON geometry. Returns null if unusable.
  static RouteResult? parseOsrm(String body) {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      if (j['code'] != 'Ok') return null;
      final r = (j['routes'] as List).first as Map<String, dynamic>;
      final coords = ((r['geometry'] as Map)['coordinates'] as List)
          .map((c) => LatLng(((c as List)[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      if (coords.length < 2) return null;
      return RouteResult(
        points: coords,
        distanceM: (r['distance'] as num).toDouble(),
        duration: Duration(seconds: (r['duration'] as num).round()),
        byRoad: true,
      );
    } catch (_) {
      return null;
    }
  }
}

// ---------- formatting helpers ----------

String formatDistance(double m) => m < 1000 ? '${(m / 10).round() * 10} m' : '${(m / 1000).toStringAsFixed(m < 10000 ? 1 : 0)} km';

String formatEta(Duration d) {
  if (d.inMinutes < 1) return '< 1 min';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  return '${d.inHours} h ${d.inMinutes % 60} min';
}

/// Heading in degrees (0 = north) → "north", "south-east", …
String compassDirection(double heading) {
  if (!heading.isFinite || heading < 0) return '';
  const names = ['north', 'north-east', 'east', 'south-east', 'south', 'south-west', 'west', 'north-west'];
  return names[((heading % 360) / 45).round() % 8];
}

/// Human description of how the child is moving, from speed in m/s.
String movementLabel(double? speedMps) {
  final kmh = (speedMps ?? -1) * 3.6;
  if (kmh < 0) return 'Not moving';
  if (kmh < 1.5) return 'Not moving';
  if (kmh < 7) return 'Walking';
  if (kmh < 25) return 'Cycling or slow traffic';
  return 'In a vehicle';
}

/// Initial bearing from a to b in degrees (0 = north).
double bearing(LatLng a, LatLng b) {
  final p1 = a.latitudeInRad, p2 = b.latitudeInRad, dl = b.longitudeInRad - a.longitudeInRad;
  final y = math.sin(dl) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}
