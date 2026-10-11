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
