import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakawala/core/theme.dart';
import 'package:rakawala/features/child/sos_button.dart';
import 'package:rakawala/widgets/common.dart';

void main() {
  Widget host(Widget child) => MaterialApp(theme: AppTheme.light(), home: Scaffold(body: Center(child: child)));

  testWidgets('SOS fires only after a full hold, not a tap', (tester) async {
    var fired = 0;
    await tester.pumpWidget(host(SosButton(onTriggered: () => fired++)));

    // Quick tap: nothing.
    await tester.tap(find.text('SOS'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(fired, 0);

    // Hold for 2.1 s: fires once.
    final gesture = await tester.startGesture(tester.getCenter(find.text('SOS')));
    for (var i = 0; i < 22; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.up();
    await tester.pump();
    expect(fired, 1);
  });

  testWidgets('SOS released early does not fire', (tester) async {
    var fired = 0;
    await tester.pumpWidget(host(SosButton(onTriggered: () => fired++)));
    final gesture = await tester.startGesture(tester.getCenter(find.text('SOS')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.up();
    await tester.pump(const Duration(seconds: 3));
    expect(fired, 0);
  });

  testWidgets('battery badge warns when low', (tester) async {
    await tester.pumpWidget(host(const BatteryBadge(level: 9)));
    expect(find.text('9%'), findsOneWidget);
    expect(find.byIcon(Icons.battery_alert_rounded), findsOneWidget);
  });

  test('timeAgo', () {
    expect(timeAgo(null), 'never');
    expect(timeAgo(DateTime.now()), 'just now');
    expect(timeAgo(DateTime.now().subtract(const Duration(minutes: 5))), '5 min ago');
  });
}
