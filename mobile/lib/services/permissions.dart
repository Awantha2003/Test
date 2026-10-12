import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

enum SharingReadiness { ready, needsLocation, needsAlways, serviceOff, denied }

/// Location permissions for the child device. Store policy requires that we show our own
/// prominent disclosure (see PermissionsScreen) before the OS dialogs below.
class Permissions {
  static Future<SharingReadiness> check() async {
    if (!await Geolocator.isLocationServiceEnabled()) return SharingReadiness.serviceOff;
    final p = await Geolocator.checkPermission();
    return switch (p) {
      LocationPermission.always => SharingReadiness.ready,
      LocationPermission.whileInUse => SharingReadiness.needsAlways,
      LocationPermission.deniedForever => SharingReadiness.denied,
      _ => SharingReadiness.needsLocation,
    };
  }

  /// Foreground first, then "Allow all the time". Android 11+ requires the two steps.
  static Future<SharingReadiness> request() async {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.whileInUse) {
      final bg = await Permission.locationAlways.request();
      if (bg.isGranted) p = LocationPermission.always;
    }
    await Permission.notification.request();
    return check();
  }

  static Future<void> requestMicrophone() async {
    await Permission.microphone.request();
    await Permission.speech.request();
  }

  static Future<void> openSettings() => openAppSettings();
}
