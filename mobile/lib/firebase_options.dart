// Firebase client configuration.
//
// Replace this file by running `flutterfire configure` for your project, or pass the
// values with --dart-define (see mobile/README.md). These values are not secrets:
// access is enforced by Firestore rules, Cloud Functions checks and App Check.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'rakawala-dev');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID', defaultValue: '000000000000');

  static FirebaseOptions get currentPlatform => switch (defaultTargetPlatform) {
        TargetPlatform.iOS => ios,
        _ => android,
      };

  static const android = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_ANDROID_API_KEY', defaultValue: 'replace-me'),
    appId: String.fromEnvironment('FIREBASE_ANDROID_APP_ID', defaultValue: '1:000000000000:android:0000000000000000'),
    messagingSenderId: _senderId,
    projectId: _projectId,
    storageBucket: '$_projectId.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_IOS_API_KEY', defaultValue: 'replace-me'),
    appId: String.fromEnvironment('FIREBASE_IOS_APP_ID', defaultValue: '1:000000000000:ios:0000000000000000'),
    messagingSenderId: _senderId,
    projectId: _projectId,
    storageBucket: '$_projectId.firebasestorage.app',
    iosBundleId: 'lk.rakawala.rakawala',
  );
}
