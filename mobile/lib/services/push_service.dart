import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Push notifications for guardians: channel setup, token registration, foreground display.
class PushService {
  static final _local = FlutterLocalNotificationsPlugin();
  static final _messaging = FirebaseMessaging.instance;
  static final _taps = StreamController<Map<String, dynamic>>.broadcast();

  /// Emits the data payload when a notification is tapped (used to open the SOS screen).
  static Stream<Map<String, dynamic>> get taps => _taps.stream;

  static const sosChannel = AndroidNotificationChannel(
    'sos',
    'SOS emergencies',
    description: 'Emergency alerts from your children. Always loud.',
    importance: Importance.max,
    bypassDnd: true,
    playSound: true,
    enableVibration: true,
  );

  static const alertsChannel = AndroidNotificationChannel(
    'alerts',
    'Safety alerts',
    description: 'Arrivals, departures, late arrivals, low battery and more.',
    importance: Importance.high,
  );

  static Future<void> init() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) _taps.add(Map<String, dynamic>.from(jsonDecode(r.payload!) as Map));
      },
    );
    final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(sosChannel);
    await android?.createNotificationChannel(alertsChannel);

    FirebaseMessaging.onMessage.listen(_showForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _taps.add(m.data));
    final initial = await _messaging.getInitialMessage();
    if (initial != null) scheduleMicrotask(() => _taps.add(initial.data));
  }

  /// Ask permission and store this device's token so the backend can reach it.
  static Future<void> registerGuardianDevice(String uid) async {
    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true, criticalAlert: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(uid, token);
    _messaging.onTokenRefresh.listen((t) => _saveToken(uid, t));
  }

  static Future<void> unregister(String uid) async {
    final token = await _messaging.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('devices').doc(_id(token)).delete();
    }
    await _messaging.deleteToken();
  }

  static String _id(String token) => sha256.convert(utf8.encode(token)).toString().substring(0, 40);

  static Future<void> _saveToken(String uid, String token) => FirebaseFirestore.instance.collection('users').doc(uid).collection('devices').doc(_id(token)).set({
        'token': token,
        'platform': switch (defaultTargetPlatform) { TargetPlatform.iOS => 'ios', _ => 'android' },
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> _showForeground(RemoteMessage m) async {
    final n = m.notification;
    if (n == null) return;
    final isSos = m.data['type'] == 'sos';
    final channel = isSos ? sosChannel : alertsChannel;
    await _local.show(
      id: m.messageId.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: isSos ? Priority.max : Priority.high,
          fullScreenIntent: isSos,
          category: isSos ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.status,
          color: isSos ? const Color(0xFFDC2626) : null,
        ),
        iOS: DarwinNotificationDetails(interruptionLevel: isSos ? InterruptionLevel.critical : InterruptionLevel.timeSensitive),
      ),
      payload: jsonEncode(m.data),
    );
  }
}
