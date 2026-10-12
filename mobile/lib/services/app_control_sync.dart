import 'dart:async';

import 'package:app_control/app_control.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Child phone side of app controls (Android):
///  - receives the guardian's rules and hands them to the on-device blocker,
///  - reports today's app usage, installed apps and whether controls are switched on.
class AppControlSync {
  AppControlSync({required this.familyId, required this.childId, FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final String familyId;
  final String childId;
  final FirebaseFirestore _db;

  static const reportEvery = Duration(minutes: 15);
  static const maxApps = 200;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _rulesSub;
  Timer? _timer;
  AppRules _rules = AppRules.empty;
  AppRules get rules => _rules;

  DocumentReference<Map<String, dynamic>> get _rulesRef => _db.collection('families').doc(familyId).collection('appRules').doc(childId);
  DocumentReference<Map<String, dynamic>> get _usageRef => _db.collection('families').doc(familyId).collection('appUsage').doc(childId);

  Future<void> start() async {
    if (!AppControl.supported) return;
    _rulesSub = _rulesRef.snapshots().listen((d) async {
      _rules = AppRules.fromMap(d.data());
      await AppControl.setRules(_rules);
    }, onError: (Object e) => debugPrint('app rules listener: $e'));
    _timer = Timer.periodic(reportEvery, (_) => report());
    unawaited(report());
  }

  Future<void> stop() async {
    await _rulesSub?.cancel();
    _timer?.cancel();
  }

  Future<void> report() async {
    if (!AppControl.supported) return;
    try {
      final status = await AppControl.status();
      final installed = await AppControl.installedApps();
      final usage = status.usageAccess ? await AppControl.usageTodayMinutes() : const <String, int>{};
      await _usageRef.set(buildUsageDoc(status: status, installed: installed, usageMin: usage, now: DateTime.now()));
    } catch (e) {
      debugPrint('app usage report failed: $e');
    }
  }

  /// Exactly the shape the security rules accept for `appUsage/{childId}`.
  @visibleForTesting
  static Map<String, Object?> buildUsageDoc({
    required ControlsStatus status,
    required List<InstalledApp> installed,
    required Map<String, int> usageMin,
    required DateTime now,
  }) {
    final names = {for (final a in installed) a.pkg: a.name};
    final top = usageMin.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final apps = {
      for (final e in top.take(maxApps)) e.key: {'name': names[e.key] ?? e.key, 'minutes': e.value.clamp(0, 1440)},
    };
    final total = usageMin.values.fold<int>(0, (s, m) => s + m).clamp(0, 1440);
    return {
      'date': DateFormat('yyyy-MM-dd').format(now),
      'apps': apps,
      'totalMin': total,
      'installed': installed.take(600).map((a) => a.toMap()).toList(),
      'controls': {'usageAccess': status.usageAccess, 'accessibility': status.accessibility, 'platform': 'android'},
      'ts': FieldValue.serverTimestamp(),
    };
  }
}
