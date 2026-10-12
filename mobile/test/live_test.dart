import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:rakawala/data/models.dart';
import 'package:rakawala/services/location_tracker.dart';
import 'package:rakawala/services/routing.dart';

void main() {
  test('OSRM response is parsed into a road route', () {
    const body = '{"code":"Ok","routes":[{"distance":2350.5,"duration":412.3,'
        '"geometry":{"type":"LineString","coordinates":[[79.86,6.92],[79.861,6.925],[79.87,6.93]]}}]}';
    final r = Routing.parseOsrm(body)!;
    expect(r.byRoad, isTrue);
    expect(r.points.first, const LatLng(6.92, 79.86), reason: 'GeoJSON is [lng, lat]');
    expect(r.points.length, 3);
    expect(r.duration, const Duration(seconds: 412));
  });

  test('bad or failed routing responses fall back (null)', () {
    expect(Routing.parseOsrm('{"code":"NoRoute","routes":[]}'), isNull);
    expect(Routing.parseOsrm('not json'), isNull);
  });

  test('no routing server configured: straight line with real distance', () async {
    final r = await Routing(baseUrl: '').route(const LatLng(6.9271, 79.8612), const LatLng(6.9344, 79.8428));
    expect(r.byRoad, isFalse);
    expect(r.points.length, 2);
    expect(r.distanceM, closeTo(2190, 150));
  });

  test('formatting', () {
    expect(formatDistance(347), '350 m');
    expect(formatDistance(2350), '2.4 km');
    expect(formatDistance(23500), '24 km');
    expect(formatEta(const Duration(seconds: 30)), '< 1 min');
    expect(formatEta(const Duration(minutes: 75)), '1 h 15 min');
    expect(compassDirection(0), 'north');
    expect(compassDirection(135), 'south-east');
    expect(compassDirection(350), 'north');
    expect(compassDirection(-1), '');
    expect(movementLabel(0.2), 'Not moving');
    expect(movementLabel(1.4), 'Walking');
    expect(movementLabel(15), 'In a vehicle');
  });

  test('bearing points the right way', () {
    expect(bearing(const LatLng(6.9, 79.8), const LatLng(7.0, 79.8)), closeTo(0, 1));
    expect(bearing(const LatLng(6.9, 79.8), const LatLng(6.9, 79.9)), closeTo(90, 1));
  });

  test('live mode asks the GPS for much faster updates', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final normal = LocationTracker.positionSettings(live: false) as AndroidSettings;
    final live = LocationTracker.positionSettings(live: true) as AndroidSettings;
    expect(live.distanceFilter, lessThan(normal.distanceFilter));
    expect(live.intervalDuration!.inSeconds, 5);
    debugDefaultTargetPlatformOverride = null;
  });

  test('child live flag follows liveUntil', () {
    Child c(DateTime? until) => Child(id: 'c', name: 'N', color: const Color(0xFF000000), paired: true, settings: const ChildSettings(), liveUntil: until);
    expect(c(DateTime.now().add(const Duration(minutes: 5))).isLive, isTrue);
    expect(c(DateTime.now().subtract(const Duration(seconds: 1))).isLive, isFalse);
    expect(c(null).isLive, isFalse);
  });
}
