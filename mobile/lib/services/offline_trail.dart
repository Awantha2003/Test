import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One location recorded while the phone had no data connection.
class TrailPoint {
  TrailPoint({required this.lat, required this.lng, required this.accuracy, this.speed, this.battery, required this.ts});
  final double lat;
  final double lng;
  final double accuracy;
  final double? speed;
  final int? battery;
  final int ts; // epoch ms (device clock)

  Map<String, Object?> toJson() => {
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        if (speed != null && speed! >= 0) 'speed': speed,
        'battery': ?battery,
        'ts': ts,
      };

  static TrailPoint fromJson(Map<String, dynamic> m) => TrailPoint(
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        accuracy: (m['accuracy'] as num).toDouble(),
        speed: (m['speed'] as num?)?.toDouble(),
        battery: (m['battery'] as num?)?.toInt(),
        ts: (m['ts'] as num).toInt(),
      );
}

/// On-device queue of locations recorded without signal. Survives app restarts and
/// works across isolates (the Android background service writes, the UI reads the count).
class OfflineTrailBuffer {
  OfflineTrailBuffer([SharedPreferencesAsync? prefs]) : _prefs = prefs ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _prefs;

  static const _key = 'offline_trail_v1';

  /// ~2 days of movement; older points are dropped first.
  static const maxPoints = 2000;

  Future<List<TrailPoint>> all() async {
    final raw = await _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => TrailPoint.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      await clear(); // corrupt storage must never block location sharing
      return [];
    }
  }

  Future<int> count() async => (await all()).length;

  Future<void> add(TrailPoint p) async {
    final list = await all()..add(p);
    final trimmed = list.length > maxPoints ? list.sublist(list.length - maxPoints) : list;
    await _prefs.setString(_key, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }

  /// Remove the first [n] points (the ones just uploaded), keeping any added meanwhile.
  Future<void> removeFirst(int n) async {
    final list = await all();
    final rest = n >= list.length ? <TrailPoint>[] : list.sublist(n);
    if (rest.isEmpty) {
      await clear();
    } else {
      await _prefs.setString(_key, jsonEncode(rest.map((e) => e.toJson()).toList()));
    }
  }

  Future<void> clear() => _prefs.remove(_key);
}
