import 'package:cloud_functions/cloud_functions.dart';

import '../core/config.dart';

/// User-facing error raised by backend calls. The message is safe to show.
class ApiException implements Exception {
  ApiException(this.message, [this.code]);
  final String message;
  final String? code;
  @override
  String toString() => message;
}

/// Typed wrappers around the Cloud Functions callables.
class Api {
  Api([FirebaseFunctions? functions]) : _fn = functions ?? FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion);
  final FirebaseFunctions _fn;

  Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic>? data]) async {
    try {
      final res = await _fn.httpsCallable(name, options: HttpsCallableOptions(timeout: const Duration(seconds: 30))).call<Object?>(data ?? {});
      final v = res.data;
      return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      throw ApiException(_friendly(e), e.code);
    }
  }

  String _friendly(FirebaseFunctionsException e) => switch (e.code) {
        'unavailable' || 'deadline-exceeded' => 'No connection. Please check your internet and try again.',
        'unauthenticated' => 'Please sign in again.',
        'internal' => 'Something went wrong on our side. Please try again.',
        _ => e.message ?? 'Something went wrong.',
      };

  // Family
  Future<String> createFamily({required String familyName, required String displayName, String? phone}) async =>
      (await _call('createFamily', {'familyName': familyName, 'displayName': displayName, if (phone != null && phone.isNotEmpty) 'phone': phone}))['familyId'] as String;
  Future<Map<String, dynamic>> getUsage() => _call('getUsage');
  Future<void> deleteMyAccount() => _call('deleteMyAccount');

  // Places & schedules
  Future<String> savePlace(Map<String, dynamic> place) async => (await _call('savePlace', place))['id'] as String;
  Future<void> deletePlace(String id) => _call('deletePlace', {'id': id});
  Future<String> saveSchedule(Map<String, dynamic> s) async => (await _call('saveSchedule', s))['id'] as String;
  Future<void> deleteSchedule(String id) => _call('deleteSchedule', {'id': id});

  // Pairing
  Future<({String code, DateTime expiresAt})> createChildCode(String childName, {String? childId}) async {
    final r = await _call('createPairingCode', {'kind': 'child', 'childName': childName, 'childId': ?childId});
    return (code: r['code'] as String, expiresAt: DateTime.fromMillisecondsSinceEpoch(r['expiresAt'] as int));
  }

  Future<({String code, DateTime expiresAt})> createGuardianInvite() async {
    final r = await _call('createPairingCode', {'kind': 'guardian'});
    return (code: r['code'] as String, expiresAt: DateTime.fromMillisecondsSinceEpoch(r['expiresAt'] as int));
  }

  Future<Map<String, dynamic>> redeemPairingCode({required String code, required String deviceName, required String platform}) =>
      _call('redeemPairingCode', {'code': code, 'deviceName': deviceName, 'platform': platform});
  Future<void> redeemGuardianInvite({required String code, required String displayName, String? phone}) =>
      _call('redeemGuardianInvite', {'code': code, 'displayName': displayName, if (phone != null && phone.isNotEmpty) 'phone': phone});
  Future<void> removeChild(String childId) => _call('removeChild', {'childId': childId});
  Future<void> removeGuardian(String uid) => _call('removeGuardian', {'uid': uid});

  // Safety
  Future<Map<String, dynamic>> triggerSos({double? lat, double? lng, double? accuracy, required String source, int? battery}) => _call('triggerSos', {
        'position': lat == null || lng == null ? null : {'lat': lat, 'lng': lng, 'accuracy': ?accuracy},
        'source': source,
        'battery': ?battery,
      });
  Future<void> checkIn({double? lat, double? lng, String? message}) => _call('checkIn', {
        'position': lat == null || lng == null ? null : {'lat': lat, 'lng': lng},
        'message': ?message,
      });
  Future<void> resolveAlert(String alertId, {String status = 'resolved', String? note}) =>
      _call('resolveAlert', {'alertId': alertId, 'status': status, 'note': ?note});

  // No signal
  Future<int> uploadOfflineTrail(List<Map<String, Object?>> points) async => ((await _call('uploadOfflineTrail', {'points': points}))['stored'] as num?)?.toInt() ?? 0;

  /// [minutes] = 0 ends the window early. Guardians pass [childId]; a child phone omits it.
  Future<void> setOfflineWindow({String? childId, required int minutes, String? reason}) =>
      _call('setOfflineWindow', {'childId': ?childId, 'minutes': minutes, 'reason': ?reason});

  // Billing
  Future<Map<String, dynamic>> createCheckout(String planId) => _call('createCheckout', {'planId': planId, 'channel': 'app'});
}
