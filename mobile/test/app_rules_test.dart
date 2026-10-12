import 'package:app_control/app_control.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakawala/services/app_control_sync.dart';

// 2026-10-12 is a Monday.
DateTime at(int day, int h, int m) => DateTime(2026, 10, day, h, m);

void main() {
  group('time windows', () {
    test('school time: weekdays 07:30–13:30', () {
      const w = TimeWindow.schoolTime;
      expect(w.isActiveAt(at(12, 7, 29)), isFalse);
      expect(w.isActiveAt(at(12, 7, 30)), isTrue);
      expect(w.isActiveAt(at(12, 13, 29)), isTrue);
      expect(w.isActiveAt(at(12, 13, 30)), isFalse, reason: 'end is exclusive');
      expect(w.isActiveAt(at(17, 9, 0)), isFalse, reason: 'Saturday');
    });

    test('bedtime crosses midnight', () {
      const w = TimeWindow(id: 'b', label: 'Bedtime', days: ['sun', 'mon', 'tue', 'wed', 'thu'], start: '21:30', end: '06:00');
      expect(w.isActiveAt(at(12, 22, 0)), isTrue, reason: 'Monday night');
      expect(w.isActiveAt(at(13, 5, 59)), isTrue, reason: 'Tuesday early morning, from Monday\'s window');
      expect(w.isActiveAt(at(13, 6, 0)), isFalse);
      expect(w.isActiveAt(at(16, 23, 0)), isFalse, reason: 'Friday night is not listed');
      expect(w.isActiveAt(at(17, 2, 0)), isFalse, reason: 'Saturday early morning belongs to Friday');
      expect(w.isActiveAt(at(12, 2, 0)), isTrue, reason: 'Monday early morning belongs to Sunday');
    });

    test('inactive or zero-length windows never apply', () {
      expect(TimeWindow.schoolTime.copyWith(active: false).isActiveAt(at(12, 9, 0)), isFalse);
      expect(TimeWindow.schoolTime.copyWith(start: '09:00', end: '09:00').isActiveAt(at(12, 9, 0)), isFalse);
    });
  });

  group('rule engine', () {
    const tiktok = 'com.zhiliaoapp.musically', youtube = 'com.google.android.youtube', maths = 'lk.edu.maths';
    final rules = AppRules(
      apps: {
        tiktok: const AppRule(mode: AppMode.block),
        youtube: const AppRule(mode: AppMode.limit, limitMin: 60),
        maths: const AppRule(mode: AppMode.always),
      },
      schedules: const [TimeWindow.schoolTime],
      dailyLimitMin: 180,
    );

    test('blocked apps are always blocked', () {
      expect(rules.evaluate(tiktok, at(17, 20, 0)).blocked, isTrue);
    });

    test('school time pauses normal apps but not "always" apps', () {
      expect(rules.evaluate('com.whatsapp', at(12, 9, 0)).reason, contains('School time'));
      expect(rules.evaluate(maths, at(12, 9, 0)).blocked, isFalse);
      expect(rules.evaluate('com.whatsapp', at(12, 15, 0)).blocked, isFalse);
    });

    test('per-app daily limit', () {
      expect(rules.evaluate(youtube, at(12, 16, 0), usedMin: 59).blocked, isFalse);
      expect(rules.evaluate(youtube, at(12, 16, 0), usedMin: 60).reason, contains('60 min'));
    });

    test('total screen-time limit (but "always" apps still work)', () {
      expect(rules.evaluate('com.whatsapp', at(12, 16, 0), totalMin: 180).blocked, isTrue);
      expect(rules.evaluate(maths, at(12, 16, 0), totalMin: 500).blocked, isFalse);
    });

    test('no rules = nothing blocked', () {
      expect(AppRules.empty.evaluate(tiktok, at(12, 9, 0)).blocked, isFalse);
    });

    test('round-trips through the Firestore / Android JSON shape', () {
      final back = AppRules.fromMap(rules.toMap());
      expect(back.ruleFor(youtube).limitMin, 60);
      expect(back.ruleFor(tiktok).mode, AppMode.block);
      expect(back.schedules.single.start, '07:30');
      expect(back.dailyLimitMin, 180);
      expect((rules.toMap()['apps'] as Map).containsKey('com.unlisted'), isFalse, reason: 'default "allow" isn\'t stored');
    });
  });

  test('usage report matches the security-rules shape', () {
    final doc = AppControlSync.buildUsageDoc(
      status: const ControlsStatus(supported: true, usageAccess: true, accessibility: false),
      installed: const [InstalledApp('com.whatsapp', 'WhatsApp'), InstalledApp('com.google.android.youtube', 'YouTube')],
      usageMin: const {'com.whatsapp': 42, 'com.google.android.youtube': 2000},
      now: DateTime(2026, 10, 12, 18),
    );
    expect(doc.keys.toSet(), {'date', 'apps', 'totalMin', 'installed', 'controls', 'ts'});
    expect(doc['date'], '2026-10-12');
    expect(doc['totalMin'], 1440, reason: 'clamped to a day');
    expect(((doc['apps'] as Map)['com.whatsapp'] as Map)['name'], 'WhatsApp');
    expect((doc['controls'] as Map).keys.toSet(), {'usageAccess', 'accessibility', 'platform'});
    expect(doc['ts'], isA<FieldValue>());
  });
}
