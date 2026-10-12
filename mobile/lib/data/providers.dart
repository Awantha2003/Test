import 'package:app_control/app_rules.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'models.dart';

final apiProvider = Provider<Api>((ref) => Api());
final _db = FirebaseFirestore.instance;

/// Auth + custom claims. Re-emits whenever the ID token refreshes (e.g. after createFamily).
final sessionProvider = StreamProvider<Session?>((ref) {
  return FirebaseAuth.instance.idTokenChanges().asyncMap((user) async {
    if (user == null) return null;
    final token = await user.getIdTokenResult();
    final c = token.claims ?? const {};
    return Session(
      uid: user.uid,
      role: c['role'] as String?,
      familyId: c['familyId'] as String?,
      email: user.email,
      emailVerified: user.emailVerified || token.signInProvider != 'password',
      isAdmin: c['admin'] == true,
    );
  });
});

String _requireFamily(Ref ref) {
  final fid = ref.watch(sessionProvider).value?.familyId;
  if (fid == null) throw StateError('No family');
  return fid;
}

CollectionReference<Map<String, dynamic>> familyCol(String fid, String sub) => _db.collection('families').doc(fid).collection(sub);

final familyProvider = StreamProvider<Family>((ref) {
  final fid = _requireFamily(ref);
  return _db.collection('families').doc(fid).snapshots().map(Family.fromDoc);
});

final childrenProvider = StreamProvider<List<Child>>((ref) {
  final fid = _requireFamily(ref);
  return familyCol(fid, 'children').snapshots().map((s) => s.docs.map(Child.fromDoc).toList()..sort((a, b) => a.name.compareTo(b.name)));
});

final liveProvider = StreamProvider<Map<String, LiveLocation>>((ref) {
  final fid = _requireFamily(ref);
  return familyCol(fid, 'live').snapshots().map((s) => {for (final d in s.docs) d.id: LiveLocation.fromDoc(d)});
});

final placesProvider = StreamProvider<List<Place>>((ref) {
  final fid = _requireFamily(ref);
  return familyCol(fid, 'places').snapshots().map((s) => s.docs.map(Place.fromDoc).toList()..sort((a, b) => a.name.compareTo(b.name)));
});

final schedulesProvider = StreamProvider<List<Schedule>>((ref) {
  final fid = _requireFamily(ref);
  return familyCol(fid, 'schedules').snapshots().map((s) => s.docs.map(Schedule.fromDoc).toList());
});

final alertsProvider = StreamProvider<List<AlertItem>>((ref) {
  final fid = _requireFamily(ref);
  return familyCol(fid, 'alerts').orderBy('createdAt', descending: true).limit(100).snapshots().map((s) => s.docs.map(AlertItem.fromDoc).toList());
});

final openSosProvider = Provider<List<AlertItem>>((ref) {
  final alerts = ref.watch(alertsProvider).value ?? const [];
  return alerts.where((a) => a.isOpenSos).toList();
});

final membersProvider = StreamProvider<List<Member>>((ref) {
  final fid = _requireFamily(ref);
  return familyCol(fid, 'members').snapshots().map((s) => s.docs.map(Member.fromDoc).toList());
});

final plansProvider = StreamProvider<List<Plan>>((ref) {
  return _db.collection('plans').where('active', isEqualTo: true).snapshots().map((s) => s.docs.map(Plan.fromDoc).toList()..sort((a, b) => a.order.compareTo(b.order)));
});

final historyProvider = StreamProvider.family<List<HistoryPoint>, String>((ref, childId) {
  final fid = _requireFamily(ref);
  final since = Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));
  return familyCol(fid, 'history')
      .where('childId', isEqualTo: childId)
      .where('ts', isGreaterThan: since)
      .orderBy('ts', descending: true)
      .limit(500)
      .snapshots()
      .map((s) => s.docs.map(HistoryPoint.fromDoc).toList().reversed.toList());
});

/// Child-device view of its own record (settings such as guard mode and safe-word).
final myChildProvider = StreamProvider<Child?>((ref) {
  final s = ref.watch(sessionProvider).value;
  if (s == null || !s.isChild) return Stream.value(null);
  return familyCol(s.familyId!, 'children').doc(s.uid).snapshots().map((d) => d.exists ? Child.fromDoc(d) : null);
});

/// Guardians, as seen from the child phone (for "Call Amma" and offline SMS).
final guardiansProvider = StreamProvider<List<Member>>((ref) {
  final s = ref.watch(sessionProvider).value;
  if (s?.familyId == null) return Stream.value(const []);
  return familyCol(s!.familyId!, 'members').where('role', isEqualTo: 'parent').snapshots().map((q) => q.docs.map(Member.fromDoc).toList());
});

// ---------- app controls ----------

class AppUsageReport {
  AppUsageReport({required this.date, required this.apps, required this.totalMin, required this.installed, required this.usageAccess, required this.accessibility, this.ts});
  final String date;
  final Map<String, ({String name, int minutes})> apps;
  final int totalMin;
  final List<({String pkg, String name})> installed;
  final bool usageAccess;
  final bool accessibility;
  final DateTime? ts;

  bool get controlsOn => usageAccess && accessibility;

  /// Usage numbers are for "today" on the child's phone; ignore yesterday's report.
  bool get isToday => date == '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

  static AppUsageReport fromMap(Map<String, dynamic> m) {
    final apps = <String, ({String name, int minutes})>{};
    (m['apps'] as Map?)?.forEach((k, v) {
      final mm = (v as Map).cast<String, dynamic>();
      apps[k as String] = (name: mm['name'] as String? ?? k, minutes: (mm['minutes'] as num?)?.toInt() ?? 0);
    });
    final controls = (m['controls'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AppUsageReport(
      date: m['date'] as String? ?? '',
      apps: apps,
      totalMin: (m['totalMin'] as num?)?.toInt() ?? 0,
      installed: ((m['installed'] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .map((e) => (pkg: e['pkg'] as String? ?? '', name: e['name'] as String? ?? ''))
          .where((e) => e.pkg.isNotEmpty)
          .toList(),
      usageAccess: controls['usageAccess'] == true,
      accessibility: controls['accessibility'] == true,
      ts: (m['ts'] as Timestamp?)?.toDate(),
    );
  }
}

final appUsageProvider = StreamProvider.family<AppUsageReport?, String>((ref, childId) {
  final fid = _requireFamily(ref);
  return familyCol(fid, 'appUsage').doc(childId).snapshots().map((d) => d.exists ? AppUsageReport.fromMap(d.data()!) : null);
});

final appRulesProvider = StreamProvider.family<AppRules, String>((ref, childId) {
  final s = ref.watch(sessionProvider).value;
  if (s?.familyId == null) return Stream.value(AppRules.empty);
  return familyCol(s!.familyId!, 'appRules').doc(childId).snapshots().map((d) => AppRules.fromMap(d.data()));
});

// ---------- child device protection ----------

class DeviceStatus {
  DeviceStatus({required this.locationPermission, required this.locationService, this.uninstallProtection, required this.platform, this.ts});
  final String locationPermission; // always | whileInUse | denied
  final bool locationService;
  final bool? uninstallProtection; // null on iPhone
  final String platform;
  final DateTime? ts;

  bool get fullyProtected => locationPermission == 'always' && locationService && (uninstallProtection ?? true);

  static DeviceStatus fromMap(Map<String, dynamic> m) => DeviceStatus(
        locationPermission: m['locationPermission'] as String? ?? 'denied',
        locationService: m['locationService'] as bool? ?? false,
        uninstallProtection: m['uninstallProtection'] as bool?,
        platform: m['platform'] as String? ?? 'android',
        ts: (m['ts'] as Timestamp?)?.toDate(),
      );
}

final deviceStatusProvider = StreamProvider.family<DeviceStatus?, String>((ref, childId) {
  final fid = _requireFamily(ref);
  return familyCol(fid, 'deviceStatus').doc(childId).snapshots().map((d) => d.exists ? DeviceStatus.fromMap(d.data()!) : null);
});
