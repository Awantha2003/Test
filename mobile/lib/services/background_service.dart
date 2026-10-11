import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import 'location_tracker.dart';

const sharingChannelId = 'sharing';
const sharingNotificationId = 4401;

/// Android: a foreground service (with the required persistent notification) keeps
/// location sharing alive when the app is closed. iOS has no such service; there the
/// tracker runs in the app process with "Always" permission and background mode `location`.
class BackgroundSharing {
  static final _service = FlutterBackgroundService();
  static LocationTracker? _iosTracker;

  static Future<void> configure() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final notifications = FlutterLocalNotificationsPlugin();
    await notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          sharingChannelId,
          'Location sharing',
          description: 'Shows while Rakawala is sharing location with your family.',
          importance: Importance.low,
        ));
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: backgroundEntryPoint,
        autoStart: false,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: sharingChannelId,
        initialNotificationTitle: 'Rakawala is keeping you safe',
        initialNotificationContent: 'Sharing your location with your family',
        foregroundServiceNotificationId: sharingNotificationId,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );
  }

  static Future<void> start() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (!await _service.isRunning()) await _service.startService();
    } else {
      _iosTracker ??= LocationTracker();
      await _iosTracker!.start();
    }
  }

  static Future<void> stop() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      _service.invoke('stop');
    } else {
      await _iosTracker?.stop();
    }
  }

  static Future<bool> isRunning() async =>
      defaultTargetPlatform == TargetPlatform.android ? _service.isRunning() : (_iosTracker?.running ?? false);
}

/// Runs in a separate isolate on Android.
@pragma('vm:entry-point')
Future<void> backgroundEntryPoint(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  final tracker = LocationTracker();
  await tracker.start();
  service.on('stop').listen((_) async {
    await tracker.stop();
    await service.stopSelf();
  });
}
