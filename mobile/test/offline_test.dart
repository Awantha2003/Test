import 'package:flutter_test/flutter_test.dart';
import 'package:rakawala/services/location_tracker.dart';
import 'package:rakawala/services/offline_trail.dart';
import 'package:rakawala/widgets/offline_window_sheet.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

TrailPoint pt(int i) => TrailPoint(lat: 6.9 + i / 1000, lng: 79.86, accuracy: 15, speed: 1.5, battery: 60, ts: 1760000000000 + i * 30000);

void main() {
  setUp(() => SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty());

  test('buffer keeps points in order and survives a new instance (app restart)', () async {
    await OfflineTrailBuffer().add(pt(1));
    await OfflineTrailBuffer().add(pt(2));
    final all = await OfflineTrailBuffer().all();
    expect(all.map((p) => p.ts), [pt(1).ts, pt(2).ts]);
    expect(all.first.lat, pt(1).lat);
  });

  test('buffer drops the oldest points beyond the cap', () async {
    final b = OfflineTrailBuffer();
    for (var i = 0; i < OfflineTrailBuffer.maxPoints + 5; i++) {
      await b.add(pt(i));
    }
    final all = await b.all();
    expect(all.length, OfflineTrailBuffer.maxPoints);
    expect(all.first.ts, pt(5).ts);
  });

  test('upload sends chunks and empties the buffer', () async {
    final b = OfflineTrailBuffer();
    for (var i = 0; i < 7; i++) {
      await b.add(pt(i));
    }
    final chunks = <int>[];
    final sent = await LocationTracker.uploadBuffered(b, (c) async => chunks.add(c.length), chunkSize: 3);
    expect(sent, 7);
    expect(chunks, [3, 3, 1]);
    expect(await b.count(), 0);
  });

  test('a failed upload keeps the unsent points for the next try', () async {
    final b = OfflineTrailBuffer();
    for (var i = 0; i < 5; i++) {
      await b.add(pt(i));
    }
    var calls = 0;
    await expectLater(
      LocationTracker.uploadBuffered(b, (c) async {
        if (++calls == 2) throw Exception('no signal again');
        return null;
      }, chunkSize: 2),
      throwsException,
    );
    final left = await b.all();
    expect(left.length, 3, reason: 'first chunk of 2 was accepted and removed');
    expect(left.first.ts, pt(2).ts);
  });

  test('points serialise to what the server expects', () {
    final j = TrailPoint(lat: 1, lng: 2, accuracy: 3, speed: -1, ts: 9).toJson();
    expect(j.keys.toSet(), {'lat', 'lng', 'accuracy', 'ts'}, reason: 'unknown speed and battery are omitted');
  });

  test('corrupt storage is cleared instead of crashing the tracker', () async {
    await SharedPreferencesAsyncPlatform.instance!.setString('offline_trail_v1', 'not json', const SharedPreferencesOptions());
    expect(await OfflineTrailBuffer().all(), isEmpty);
  });

  test('duration labels', () {
    expect(durationLabel(30), '30 min');
    expect(durationLabel(120), '2 h');
    expect(durationLabel(90), '1 h 30 min');
  });
}
