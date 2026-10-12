# Rakawala: Deployment & Go-Live Guide

## 0. Accounts you need

| Service | Why | Notes |
|---|---|---|
| Firebase / Google Cloud (Blaze plan) | Auth, Firestore, Functions, Hosting, FCM | Create two projects: `rakawala-dev` and `rakawala-prod` |
| PayHere merchant | LKR subscriptions | Use a sandbox account first |
| Notify.lk | SOS SMS | Needs an approved sender ID such as "Rakawala" |
| MapTiler or Stadia Maps | Production map tiles | OSM's free tiles are not allowed for production use |
| Google Play Console, Apple Developer | App stores | Background-location declaration plus a demo video is required |

## 1. Firebase project setup

1. Enable **Authentication**:
   - Turn on the Email/Password and Google providers.
   - Upgrade to **Identity Platform** and enable **TOTP MFA**. Admins need it.
2. Create **Firestore** in Native mode, region `asia-south1`.
3. Enable **App Check**:
   - Play Integrity for Android.
   - App Attest with DeviceCheck fallback for iOS.
   - reCAPTCHA Enterprise for web.
   - Turn on enforcement for Firestore after the first app release.
4. Turn on **budget alerts** in Google Cloud Billing.

## 2. Backend

```bash
cd firebase
npm ci && (cd functions && npm ci)
cp functions/.env.example functions/.env.rakawala-prod      # then edit the values

npx firebase use prod
npx firebase functions:secrets:set PAYHERE_MERCHANT_SECRET     # web domain secret
npx firebase functions:secrets:set PAYHERE_APP_MERCHANT_SECRET # mobile app package secret
npx firebase functions:secrets:set NOTIFYLK_API_KEY

npx firebase deploy --only firestore:rules,firestore:indexes,functions
```

**First admin:**
1. Create the admin user in the web login.
2. Enrol TOTP.
3. Run the grant script:
   ```bash
   cd firebase/functions
   GOOGLE_APPLICATION_CREDENTIALS=~/sa-prod.json npm run grant-admin -- you@rakawala.lk
   ```
4. Sign in to `/admin` and click **Seed default packages & content**.

## 3. PayHere

1. In the merchant portal, go to **Integrations** and add:
   - **Domain** `rakawala.lk`. Its secret goes in `PAYHERE_MERCHANT_SECRET`.
   - **App** `lk.rakawala.rakawala`. Its secret goes in `PAYHERE_APP_MERCHANT_SECRET`.
2. Set the notify URL to `https://rakawala.lk/api/payhere/notify`. Hosting rewrites this path to the function.
3. Sandbox test (do all of these before going live):
   - Buy Family with a test card. The family switches to `family_month` within seconds.
   - Re-POST the same notification. It must be ignored (idempotent).
   - Change `payhere_amount` and re-POST. It must be rejected with `amount-mismatch` or 400.
4. Set `PAYHERE_SANDBOX=false` and redeploy functions.

> ⚠️ Re-check the `hash` and `md5sig` formulas in `functions/src/lib/payhere.ts` against PayHere's current docs. The sandbox test above will fail loudly if anything differs.

## 4. Website + admin panel

```bash
cd web
cp .env.example .env.production   # fill in the Firebase web config, reCAPTCHA key and tile URL
npm ci && npm run build           # static export → web/out
cd ../firebase && npx firebase deploy --only hosting
```

- Security headers (CSP, HSTS, X-Frame-Options and others) are in `firebase/firebase.json`.
- Check the result at securityheaders.com. The target grade is A.

## 5. Mobile app

```bash
cd mobile
dart pub global activate flutterfire_cli
flutterfire configure --project=rakawala-prod   # overwrites lib/firebase_options.dart
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols \
  --dart-define=MAP_TILE_URL='https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=YOUR_KEY' \
  --dart-define=MAP_ATTRIBUTION='© MapTiler © OpenStreetMap contributors' \
  --dart-define=WEB_URL=https://rakawala.lk
flutter build ipa --release --obfuscate --split-debug-info=build/symbols  # same defines
```

- **Signing**: create `android/key.properties` with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`. It is git-ignored.
- Register the **SHA-256** of the Play app-signing key in Firebase. Play Integrity and Google Sign-In need it.
- **Google Play**:
  - Background location declaration.
  - Data safety form: location, approximate and precise, shared with family only, encrypted, deletable.
  - Families policy review.
- **App controls (Google Play)**:
  - Complete the **AccessibilityService API declaration** (parental-control use, prominent disclosure, consent screen and video). The in-app card on the child phone is the disclosure.
  - Explain `PACKAGE_USAGE_STATS` in the data safety form.
  - Expect a manual review.
- **Uninstall protection (Google Play)**:
  - It uses the Device Admin API with no policies.
  - Declare it under parental control in the Play Console permissions declaration.
  - Keep the in-app explanation on the child phone, which is the disclosure.
- **Live track routing**:
  - The road route uses an OSRM-compatible server (`--dart-define=ROUTING_URL=...`).
  - The public demo server is for testing only. Self-host OSRM with the Sri Lanka OSM extract, or use a provider.
- **iOS**:
  - Enable the Push Notifications and Background Modes capabilities in Xcode.
  - Request the **Critical Alerts** entitlement from Apple, so SOS can bypass silent mode.

## 6. Local development (emulators)

```bash
cd firebase && npx firebase emulators:start --project demo-rakawala
# functions/.env.local → ENFORCE_APP_CHECK=false, REQUIRE_ADMIN_MFA=false
cd web && NEXT_PUBLIC_USE_EMULATORS=true npm run dev
cd mobile && flutter run --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=10.0.2.2
```

## 7. Go-live checklist

- [ ] All CI green: functions tests, rules tests, web build, Flutter analyze and test.
- [ ] Security checklist in `docs/SECURITY.md` §4 completed.
- [ ] App Check enforcement turned on (Firestore and Functions).
- [ ] PayHere live mode, with a real LKR 490 purchase and refund tested.
- [ ] SMS sender ID approved, and a test SOS SMS received on Dialog, Mobitel and Hutch.
- [ ] Privacy policy and terms reviewed by a lawyer (PDPA 2022).
- [ ] Closed beta with 20 families for 2 weeks, watching battery use and alert accuracy.
