import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rakawala/core/router.dart';
import 'package:rakawala/data/models.dart';
import 'package:rakawala/services/device_status.dart';

void main() {
  test('status report matches the security-rules shape (Android)', () {
    final d = DeviceStatusReporter.buildStatusDoc(permission: LocationPermission.always, serviceOn: true, protection: true, android: true);
    expect(d.keys.toSet(), {'locationPermission', 'locationService', 'uninstallProtection', 'platform', 'appVersion', 'ts'});
    expect(d['locationPermission'], 'always');
    expect(d['uninstallProtection'], true);
    expect(d['ts'], isA<FieldValue>());
  });

  test('permission levels map to what the backend compares', () {
    String level(LocationPermission p) => DeviceStatusReporter.buildStatusDoc(permission: p, serviceOn: true, protection: false, android: true)['locationPermission'] as String;
    expect(level(LocationPermission.whileInUse), 'whileInUse');
    expect(level(LocationPermission.denied), 'denied');
    expect(level(LocationPermission.deniedForever), 'denied');
  });

  test('iPhone reports no uninstall protection (null), not "off"', () {
    final d = DeviceStatusReporter.buildStatusDoc(permission: LocationPermission.always, serviceOn: true, protection: null, android: false);
    expect(d['uninstallProtection'], isNull);
    expect(d['platform'], 'ios');
  });

  test('a paired child phone can never reach pairing, setup or parent screens', () {
    const child = Session(uid: 'c', role: 'child', familyId: 'f');
    for (final path in ['/child/pair', '/setup', '/welcome', '/auth/sign-in', '/p/settings', '/p/family']) {
      expect(redirectFor(loading: false, session: child, location: path), '/child', reason: path);
    }
  });
}
