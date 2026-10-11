# Rakawala: Security Architecture & Threat Model

This app stores the **real-time location of children**. A breach is not just a data leak; it can put a child in physical danger.
Security is therefore designed in from the start, not bolted on.

## 1. Assets

| Asset | Sensitivity |
|---|---|
| Child live location and history | **Critical** |
| SOS alerts | **Critical** (integrity and availability) |
| Guardian accounts | High (account takeover means access to the child's location) |
| Payment status | Medium (card data never touches our systems; PayHere is PCI-DSS) |
| Admin accounts | **Critical** (cross-tenant access) |

## 2. Threats (STRIDE) and controls

| Threat | Example | Control (where it lives) |
|---|---|---|
| **Spoofing** | Attacker pairs their own phone as "the child" | Pairing code: 8 chars from a 31-symbol alphabet (~8.5×10¹¹ combinations), SHA-256 hashed at rest, single-use, 10-min TTL, per-IP rate limit (10 tries / 10 min), App Check, and every guardian is alerted when a phone pairs (`functions/src/pairing.ts`) |
| Spoofing | Stolen parent password | Email verification required; optional MFA (TOTP/SMS via Identity Platform); biometric app lock; "sign out all devices" revokes refresh tokens |
| Spoofing | Fake PayHere IPN marks a family "Premium" | `md5sig` verified with merchant secret (Secret Manager) using a timing-safe compare; amount and currency checked against the plan; idempotent per `payment_id` (`functions/src/billing.ts`) |
| **Tampering** | Child token used to rewrite places or plan | Firestore rules: a child can write **only** `families/{fid}/live/{ownUid}` with a strict schema; `ts == request.time`; lat/lng range checks |
| Tampering | Parent edits own `limits`/`planId` to get Premium free | Rules forbid client writes to `planId`, `planStatus`, `limits`, `ownerUid`; only functions (Admin SDK) write them |
| **Repudiation** | "I never resolved that SOS" | Alerts store `resolvedBy` and time; admin actions are written to `auditLogs` (append-only, functions-only) |
| **Info disclosure** | Parent of family A reads family B | Every rule checks `request.auth.token.familyId == fid`; claims are only set by functions; IDs are random |
| Info disclosure | Admin snooping on children | Admin role has **no** read access to `live`/`history` in rules; SOS monitor shows metadata only |
| Info disclosure | Data kept forever | Firestore TTL on `history.expireAt` (plan-based: 1–90 days); account deletion wipes the family |
| **DoS** | SOS spam or pairing brute-force | Per-uid/IP rate limits in `rateLimits` (functions); App Check; Cloud Functions max instances; budget alerts |
| **Elevation** | User sets own `role:'admin'` | Claims only via Admin SDK; admin grant only via the offline script `functions/scripts/grant-admin.ts` with a service account; admin callables require `admin` claim **and** MFA (`sign_in_second_factor`) when `REQUIRE_ADMIN_MFA=true` |

## 3. Defence in depth

1. **Transport**: TLS everywhere (Firebase/Google front-ends). The web app sets HSTS, CSP, X-Frame-Options DENY, a strict Referrer-Policy, and a Permissions-Policy (`web/next.config.mjs`).
2. **App Check**:
   - Play Integrity (Android), App Attest (iOS) and reCAPTCHA Enterprise (web).
   - Enforced on Firestore and on all callables (`enforceAppCheck: true`).
3. **Least privilege**:
   - Roles live in custom claims, and rules deny by default.
   - Functions run with a dedicated service account. Secrets are in Secret Manager (`defineSecret`) and are never in the repo.
4. **Input validation**: every callable validates its payload with `zod`. The rules duplicate the critical checks.
5. **Mobile**:
   - Tokens are kept by the Firebase SDK (Keychain/Keystore).
   - Local secrets use `flutter_secure_storage`.
   - Biometric app lock is available for the parent app.
   - Release builds use code obfuscation (`--obfuscate --split-debug-info`).
   - No location data goes to any third-party analytics.
   - `android:allowBackup="false"` and `usesCleartextTraffic="false"`.
6. **Privacy**:
   - The voice safe-word is recognised **on-device**, and no audio is uploaded.
   - The child always sees a persistent "Rakawala is sharing your location" notification.
   - Data export and deletion are available on request (PDPA 2022).
7. **Supply chain**:
   - Dependencies are pinned through lockfiles.
   - `npm audit` and `flutter pub outdated` run in CI, and Dependabot is enabled.
8. **Monitoring**:
   - Cloud Logging alerts on pairing failures, IPN signature failures and admin actions.
   - Uptime check on `payhereNotify`.

## 4. Security test checklist (run before every release)

- [ ] `npm test` in `firebase/functions`: unit tests (signature, geofence, limits, validation).
- [ ] `npm run test:rules` in `firebase`: rules tests on the emulator (cross-tenant reads, child writes, plan tampering).
- [ ] Try pairing with an expired, used, or brute-forced code. All must fail.
- [ ] Replay a captured PayHere IPN. It must be idempotent, and a modified amount must be rejected.
- [ ] Check that a child token cannot read `places`, `history` or other children.
- [ ] Check that an admin without MFA cannot call admin functions.
- [ ] Test on a rooted/jailbroken device with App Check enforced. It must be rejected.
- [ ] Run OWASP MASVS L2 review on the mobile app.
- [ ] Check web headers with securityheaders.com (grade A).

## 5. Incident response

1. Revoke: run `revokeRefreshTokens` for the affected users, rotate secrets, and disable compromised accounts from the admin panel.
2. Contain: tighten rules or turn on the kill-switch flag `siteContent/flags.maintenance`.
3. Notify affected families within 72 hours, as required by PDPA.
4. Post-mortem: record it in `auditLogs` and in docs.
