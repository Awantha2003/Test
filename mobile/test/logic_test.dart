import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rakawala/core/router.dart';
import 'package:rakawala/data/models.dart';
import 'package:rakawala/features/auth/auth_screens.dart';
import 'package:rakawala/services/location_tracker.dart';
import 'package:rakawala/services/voice_guard.dart';

void main() {
  group('router redirect', () {
    const parent = Session(uid: 'p', role: 'parent', familyId: 'f');
    const child = Session(uid: 'c', role: 'child', familyId: 'f');
    const fresh = Session(uid: 'n', role: null);
    const unverified = Session(uid: 'u', role: null, emailVerified: false);

    test('shows splash while loading', () {
      expect(redirectFor(loading: true, session: null, location: '/'), isNull);
      expect(redirectFor(loading: true, session: null, location: '/p/map'), '/');
    });

    test('signed-out users only see public screens', () {
      expect(redirectFor(loading: false, session: null, location: '/p/map'), '/welcome');
      expect(redirectFor(loading: false, session: null, location: '/child'), '/welcome');
      expect(redirectFor(loading: false, session: null, location: '/auth/sign-in'), isNull);
      expect(redirectFor(loading: false, session: null, location: '/child/pair'), isNull);
    });

    test('child devices are locked to the child area', () {
      expect(redirectFor(loading: false, session: child, location: '/p/map'), '/child');
      expect(redirectFor(loading: false, session: child, location: '/p/settings'), '/child');
      expect(redirectFor(loading: false, session: child, location: '/child/pair'), '/child');
      expect(redirectFor(loading: false, session: child, location: '/child'), isNull);
    });

    test('parents land on the map and cannot open child mode', () {
      expect(redirectFor(loading: false, session: parent, location: '/welcome'), '/p/map');
      expect(redirectFor(loading: false, session: parent, location: '/child'), '/p/map');
      expect(redirectFor(loading: false, session: parent, location: '/p/sos/abc'), isNull);
    });

    test('new accounts verify email then set up a family', () {
      expect(redirectFor(loading: false, session: unverified, location: '/p/map'), '/auth/verify');
      expect(redirectFor(loading: false, session: fresh, location: '/p/map'), '/setup');
      expect(redirectFor(loading: false, session: fresh, location: '/setup'), isNull);
    });
  });

  group('voice safe-word', () {
    test('matches whole phrase, case and punctuation insensitive', () {
      expect(VoiceGuard.matchesSafeWord('Help, PURPLE mango!', 'purple mango'), isTrue);
      expect(VoiceGuard.matchesSafeWord('purple mango', 'Purple Mango'), isTrue);
    });
    test('does not match partial words', () {
      expect(VoiceGuard.matchesSafeWord('purple mangoes are nice', 'purple mango'), isFalse);
      expect(VoiceGuard.matchesSafeWord('mango', 'purple mango'), isFalse);
      expect(VoiceGuard.matchesSafeWord('anything', ''), isFalse);
    });
    test('works with Sinhala words', () {
      expect(VoiceGuard.matchesSafeWord('අම්මා උදව්', 'උදව්'), isTrue);
    });
  });

  group('location payload', () {
    Position pos({double speed = 3, double heading = 90}) => Position(
          latitude: 6.9,
          longitude: 79.86,
          timestamp: DateTime(2026),
          accuracy: 12,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: heading,
          headingAccuracy: 0,
          speed: speed,
          speedAccuracy: 0,
        );

    test('only contains keys the security rules allow', () {
      final p = LocationTracker.livePayload(pos(), source: 'gps', battery: 80);
      const allowed = {'lat', 'lng', 'accuracy', 'speed', 'heading', 'battery', 'charging', 'ts', 'source'};
      expect(allowed.containsAll(p.keys), isTrue);
      expect(p['ts'], isA<FieldValue>());
    });

    test('clamps out-of-range sensor values', () {
      final p = LocationTracker.livePayload(pos(speed: double.nan, heading: 999), source: 'gps', battery: 140);
      expect(p['speed'], -1.0);
      expect(p['heading'], 360.0);
      expect(p['battery'], 100);
    });
  });

  group('validation', () {
    test('password policy', () {
      expect(validatePassword('short1'), isNotNull);
      expect(validatePassword('onlyletterslong'), isNotNull);
      expect(validatePassword('lanka2026safe'), isNull);
    });
    test('email', () {
      expect(validateEmail('amma@example.lk'), isNull);
      expect(validateEmail('nope'), isNotNull);
    });
    test('colour parsing falls back safely', () {
      expect(parseHex('#DB2777').toARGB32(), 0xFFDB2777);
      expect(parseHex('red').toARGB32(), 0xFF2563EB);
    });
    test('place type wire format', () {
      expect(PlaceType.classroom.wire, 'class');
      expect(PlaceTypeX.parse('class'), PlaceType.classroom);
      expect(PlaceTypeX.parse('nonsense'), PlaceType.other);
    });
  });
}
