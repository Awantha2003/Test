import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';

import '../data/api.dart';
import '../data/models.dart';

enum SosOutcome { sentOnline, smsFallback, failed }

/// Sends an SOS as reliably as the phone allows:
///  1. grab the best position available within a few seconds,
///  2. call `triggerSos` (push + SMS to every guardian),
///  3. if offline, open the SMS app pre-filled to every guardian with a map link.
class SosService {
  SosService(this._api);
  final Api _api;

  Future<SosOutcome> trigger({required String source, required List<Member> guardians, required String childName}) async {
    unawaited(_buzz());
    final pos = await _bestPosition();
    int? battery;
    try {
      battery = await Battery().batteryLevel;
    } catch (_) {}

    try {
      await _api
          .triggerSos(lat: pos?.latitude, lng: pos?.longitude, accuracy: pos?.accuracy, source: source, battery: battery)
          .timeout(const Duration(seconds: 12));
      return SosOutcome.sentOnline;
    } catch (e) {
      debugPrint('SOS online path failed: $e');
      final ok = await smsFallback(guardians: guardians, childName: childName, pos: pos);
      return ok ? SosOutcome.smsFallback : SosOutcome.failed;
    }
  }

  static Future<bool> smsFallback({required List<Member> guardians, required String childName, Position? pos}) async {
    final phones = guardians.map((g) => g.phone).whereType<String>().where((p) => p.isNotEmpty).toList();
    if (phones.isEmpty) return false;
    final where = pos == null ? '' : ' https://maps.google.com/?q=${pos.latitude.toStringAsFixed(6)},${pos.longitude.toStringAsFixed(6)}';
    final body = 'SOS from $childName - I need help!$where';
    // Android accepts comma-separated recipients; iOS uses the first then lets the user add more.
    final uri = Uri(scheme: 'sms', path: phones.join(','), queryParameters: {'body': body});
    return launchUrl(uri);
  }

  static Future<Position?> _bestPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 6)),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  static Future<void> _buzz() async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(pattern: [0, 400, 150, 400, 150, 800]);
      }
    } catch (_) {}
  }

  static Future<void> call(String number) => launchUrl(Uri(scheme: 'tel', path: number));
}
