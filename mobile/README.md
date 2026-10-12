# Rakawala mobile app (Flutter)

One app with two modes:

- **Parent / guardian**: live map, alerts, SOS response, safe places, schedules, family and pairing, plans (PayHere), settings.
- **Child phone**: hold-to-SOS, voice safe-word, "I'm safe", call guardians, background location sharing.

```bash
flutter pub get
flutter analyze && flutter test
flutterfire configure --project=<your-project>   # writes lib/firebase_options.dart
flutter run                                       # or: --dart-define=USE_EMULATORS=true
```

Build-time settings are passed with `--dart-define`. See `lib/core/config.dart`.
Release steps are in `../docs/DEPLOYMENT.md`.
