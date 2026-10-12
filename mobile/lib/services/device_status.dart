import 'dart:async';

import 'package:app_control/app_control.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

const appVersion = '1.0.0';

/// Reports how well protected the child's phone is (location access, GPS, uninstall
/// protection). The backend compares reports and alerts guardians when something is
/// switched off, so the child can't quietly disconnect.
class DeviceStatusReporter {
  DeviceStatusReporter({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  static const every = Duration(minutes: 15);

  Timer? _timer;
  String? _lastSent;
  DateTime _lastSentAt = DateTime.fromMillisecondsSinceEpoch(0);

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => report());
    unawaited(report());
  }

  void stop() => _timer?.cancel();

  Future<void> report({bool force = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final claims = (await user.getIdTokenResult()).claims;
      final fid = claims?['familyId'] as String?;
      if (fid == null || claims?['role'] != 'child') return;

      final doc = buildStatusDoc(
        permission: await Geolocator.checkPermission(),
        serviceOn: await Geolocator.isLocationServiceEnabled(),
        protection: AppControl.supported ? await AppControl.protectionActive() : null,
        android: defaultTargetPlatform == TargetPlatform.android,
      );
      // Write on change, or at least every 15 min (acts as a heartbeat for the status).
      final key = doc.entries.where((e) => e.key != 'ts').map((e) => '${e.key}=${e.value}').join(';');
      if (!force && key == _lastSent && DateTime.now().difference(_lastSentAt) < every) return;
      await _db.collection('families').doc(fid).collection('deviceStatus').doc(user.uid).set(doc);
      _lastSent = key;
      _lastSentAt = DateTime.now();
    } catch (e) {
      debugPrint('device status report failed: $e');
    }
  }

  /// Exactly the shape the security rules accept for `deviceStatus/{childId}`.
  @visibleForTesting
  static Map<String, Object?> buildStatusDoc({required LocationPermission permission, required bool serviceOn, required bool? protection, required bool android}) => {
        'locationPermission': switch (permission) {
          LocationPermission.always => 'always',
          LocationPermission.whileInUse => 'whileInUse',
          _ => 'denied',
        },
        'locationService': serviceOn,
        'uninstallProtection': android ? (protection ?? false) : null,
        'platform': android ? 'android' : 'ios',
        'appVersion': appVersion,
        'ts': FieldValue.serverTimestamp(),
      };
}
