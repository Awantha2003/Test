import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Optional biometric/PIN lock for the guardian app, so a borrowed or stolen
/// phone doesn't reveal where the children are.
class AppLock {
  static const _storage = FlutterSecureStorage();
  static const _key = 'app_lock_enabled';
  static final _auth = LocalAuthentication();

  static Future<bool> isEnabled() async => (await _storage.read(key: _key)) == 'true';

  static Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setEnabled(bool enabled) async {
    if (enabled && !await unlock(reason: 'Confirm to turn on app lock')) return false;
    await _storage.write(key: _key, value: enabled.toString());
    return true;
  }

  static Future<bool> unlock({String reason = 'Unlock Rakawala'}) async {
    try {
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }
}
