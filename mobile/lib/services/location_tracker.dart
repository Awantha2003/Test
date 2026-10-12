import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../data/api.dart';
import 'offline_trail.dart';

/// Streams the child's position to `families/{fid}/live/{uid}`.
///
/// Battery strategy: a 25 m distance filter while moving, plus a heartbeat every 5 min
/// when still, so guardians can tell "standing still" from "phone off".
/// Runs inside the Android foreground service isolate, or the main isolate on iOS.
///
/// No signal: points are kept on the phone ([OfflineTrailBuffer]) and uploaded as one
/// batch when the connection returns, so guardians see the whole route, not a gap.
/// We deliberately don't let Firestore queue live writes offline: replayed later they
/// would carry the reconnect time and could fire stale arrive/leave alerts.
class LocationTracker {
  LocationTracker({FirebaseFirestore? db, FirebaseAuth? auth, Battery? battery, Api? api, OfflineTrailBuffer? buffer, Future<bool> Function()? hasInternet})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _battery = battery ?? Battery(),
        _api = api ?? Api(),
        _buffer = buffer ?? OfflineTrailBuffer(),
        _hasInternet = hasInternet ?? _dnsCheck;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final Battery _battery;
  final Api _api;
  final OfflineTrailBuffer _buffer;
  final Future<bool> Function() _hasInternet;

  /// Battery level at which we grab one last precise fix before the phone dies.
  static const criticalBatteryPct = 5;
  static const writeTimeout = Duration(seconds: 10);

  static const heartbeat = Duration(minutes: 5);
  static const minWriteGap = Duration(seconds: 20);

  /// While a guardian has Live track open: much faster updates for a short window.
  static const liveWriteGap = Duration(seconds: 5);

  StreamSubscription<Position>? _sub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _childSub;
  Timer? _liveEnd;
  bool _live = false;
  Timer? _heartbeat;
  DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);
  Position? _last;
  bool _flushing = false;
  bool _criticalFixDone = false;

  bool get running => _sub != null;

  Future<void> start() async {
    if (running) return;
    final user = _auth.currentUser;
    if (user == null) return;
    _listenPosition();
    _heartbeat = Timer.periodic(heartbeat, (_) => _beat());
    unawaited(_beat());
    unawaited(_watchLiveMode(user));
  }

  void _listenPosition() {
    unawaited(_sub?.cancel());
    _sub = Geolocator.getPositionStream(locationSettings: positionSettings(live: _live)).listen(
      (p) => _write(p, source: 'gps'),
      onError: (Object e) => debugPrint('location stream error: $e'),
    );
  }

  /// Normal: 25 m / ~30 s. Live (a guardian is watching): 5 m / ~5 s.
  @visibleForTesting
  static LocationSettings positionSettings({required bool live}) {
    final distance = live ? 5 : 25;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
          accuracy: live ? LocationAccuracy.best : LocationAccuracy.high,
          distanceFilter: distance,
          intervalDuration: Duration(seconds: live ? 5 : 30),
        ),
      TargetPlatform.iOS => AppleSettings(
          accuracy: live ? LocationAccuracy.best : LocationAccuracy.high,
          distanceFilter: distance,
          activityType: ActivityType.otherNavigation,
          pauseLocationUpdatesAutomatically: false,
          allowBackgroundLocationUpdates: true,
          // The blue status-bar pill tells the child sharing is on.
          showBackgroundLocationIndicator: true,
        ),
      _ => LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distance),
    };
  }

  /// Follows `liveUntil` on this child's own record (set by a guardian via setLiveTracking).
  Future<void> _watchLiveMode(User user) async {
    final fid = (await user.getIdTokenResult()).claims?['familyId'] as String?;
    if (fid == null) return;
    await _childSub?.cancel();
    _childSub = _db.collection('families').doc(fid).collection('children').doc(user.uid).snapshots().listen((d) {
      final until = (d.data()?['liveUntil'] as Timestamp?)?.toDate();
      _setLive(until != null && until.isAfter(DateTime.now()) ? until : null);
    }, onError: (Object e) => debugPrint('live-mode listener error: $e'));
  }

  void _setLive(DateTime? until) {
    _liveEnd?.cancel();
    final live = until != null;
    if (live) _liveEnd = Timer(until.difference(DateTime.now()), () => _setLive(null));
    if (live == _live) return;
    _live = live;
    if (running) _listenPosition();
    if (live) unawaited(_beat()); // send a fresh fix immediately
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _childSub?.cancel();
    _childSub = null;
    _liveEnd?.cancel();
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
    if (!force && now.difference(_lastWrite) < (_live ? liveWriteGap : minWriteGap)) return;
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
    final point = TrailPoint(
      lat: p.latitude,
      lng: p.longitude,
      accuracy: p.accuracy.clamp(0, 5000).toDouble(),
      speed: p.speed.isFinite ? p.speed : null,
      battery: level,
      ts: now.millisecondsSinceEpoch,
    );

    if (!await _hasInternet()) {
      await _buffer.add(point);
      return;
    }
    try {
      await _db
          .collection('families')
          .doc(fid)
          .collection('live')
          .doc(user.uid)
          .set(livePayload(p, source: source, battery: level, charging: charging))
          .timeout(writeTimeout);
    } catch (_) {
      // Weak signal: keep the point; the live doc catches up on the next good write.
      await _buffer.add(point);
      return;
    }
    unawaited(flushOfflineTrail());

    // About to die: one last precise fix so guardians get the best possible final location.
    if (level != null && !charging && level <= criticalBatteryPct && !_criticalFixDone) {
      _criticalFixDone = true;
      unawaited(_criticalFix());
    } else if (charging || (level ?? 100) > criticalBatteryPct + 5) {
      _criticalFixDone = false;
    }
  }

  Future<void> _criticalFix() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 15)),
      );
      await _write(p, source: 'gps', force: true);
    } catch (_) {}
  }

  /// Upload points recorded without signal, oldest first, in server-sized chunks.
  Future<int> flushOfflineTrail() async {
    if (_flushing) return 0;
    _flushing = true;
    try {
      return await uploadBuffered(_buffer, (chunk) => _api.uploadOfflineTrail(chunk));
    } catch (e) {
      debugPrint('offline trail upload failed, will retry: $e');
      return 0;
    } finally {
      _flushing = false;
    }
  }

  /// Sends the buffer in chunks of [chunkSize]; each chunk is removed only after the
  /// server accepted it, so a failure mid-way never loses or duplicates points.
  @visibleForTesting
  static Future<int> uploadBuffered(OfflineTrailBuffer buffer, Future<Object?> Function(List<Map<String, Object?>> chunk) upload, {int chunkSize = 500}) async {
    var sent = 0;
    while (true) {
      final pending = await buffer.all();
      if (pending.isEmpty) return sent;
      final chunk = pending.take(chunkSize).toList();
      await upload(chunk.map((e) => e.toJson()).toList());
      await buffer.removeFirst(chunk.length);
      sent += chunk.length;
    }
  }

  static Future<bool> _dnsCheck() async {
    try {
      final r = await InternetAddress.lookup('firestore.googleapis.com').timeout(const Duration(seconds: 4));
      return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
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
