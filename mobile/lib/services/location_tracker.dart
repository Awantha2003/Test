import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Streams the child's position to `families/{fid}/live/{uid}`.
///
/// Battery strategy: a 25 m distance filter while moving, plus a heartbeat every 5 min
/// when still, so guardians can tell "standing still" from "phone off".
/// Runs inside the Android foreground service isolate, or the main isolate on iOS.
class LocationTracker {
  LocationTracker({FirebaseFirestore? db, FirebaseAuth? auth, Battery? battery})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _battery = battery ?? Battery();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final Battery _battery;

  static const heartbeat = Duration(minutes: 5);
  static const minWriteGap = Duration(seconds: 20);

  StreamSubscription<Position>? _sub;
  Timer? _heartbeat;
  DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);
  Position? _last;

  bool get running => _sub != null;

  Future<void> start() async {
    if (running) return;
    final user = _auth.currentUser;
    if (user == null) return;

    final settings = switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
          intervalDuration: const Duration(seconds: 30),
        ),
      TargetPlatform.iOS => AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
          activityType: ActivityType.otherNavigation,
          pauseLocationUpdatesAutomatically: false,
          allowBackgroundLocationUpdates: true,
          // The blue status-bar pill tells the child sharing is on.
          showBackgroundLocationIndicator: true,
        ),
      _ => const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25),
    };

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (p) => _write(p, source: 'gps'),
      onError: (Object e) => debugPrint('location stream error: $e'),
    );
    _heartbeat = Timer.periodic(heartbeat, (_) => _beat());
    unawaited(_beat());
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  Future<void> _beat() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 20)),
      );
      await _write(p, source: 'heartbeat', force: true);
    } catch (_) {
      final p = _last ?? await Geolocator.getLastKnownPosition();
      if (p != null) await _write(p, source: 'heartbeat', force: true);
    }
  }

  Future<void> _write(Position p, {required String source, bool force = false}) async {
    _last = p;
    final now = DateTime.now();
    if (!force && now.difference(_lastWrite) < minWriteGap) return;
    final user = _auth.currentUser;
    if (user == null) return;
    final token = await user.getIdTokenResult();
    final fid = token.claims?['familyId'] as String?;
    if (fid == null || token.claims?['role'] != 'child') return;

    int? level;
    bool charging = false;
    try {
      level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      charging = state == BatteryState.charging || state == BatteryState.full;
    } catch (_) {}

    _lastWrite = now;
    await _db.collection('families').doc(fid).collection('live').doc(user.uid).set(livePayload(p, source: source, battery: level, charging: charging));
  }

  /// Exactly the keys the security rules allow; `ts` must be the server time.
  @visibleForTesting
  static Map<String, Object?> livePayload(Position p, {required String source, int? battery, bool charging = false}) => {
        'lat': p.latitude,
        'lng': p.longitude,
        'accuracy': p.accuracy.clamp(0, 100000).toDouble(),
        'speed': p.speed.isFinite ? p.speed.clamp(-1, 200).toDouble() : -1.0,
        'heading': p.heading.isFinite ? p.heading.clamp(-1, 360).toDouble() : -1.0,
        if (battery != null) 'battery': battery.clamp(0, 100),
        'charging': charging,
        'ts': FieldValue.serverTimestamp(),
        'source': source,
      };
}
