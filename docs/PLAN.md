# Rakawala: A-to-Z Product & Engineering Plan

## 1. Product overview

**Who uses it**

| Actor | Surface | What they do |
|---|---|---|
| Parent / Guardian | Flutter app (Android/iOS) + web dashboard | Live map, places, schedules, alerts, SOS response, billing |
| Child | Flutter app in **Child mode** | Shares location, SOS button, voice safe-word, "I'm safe" check-in |
| Admin (us) | Web admin panel | Users, families, plans/packages, payments, SOS monitor, website content, audit log |
| Visitor | Public website | Learns about the product, sees pricing, signs up |

**Core features (MVP: built in this repo)**

1. Live map of every child. Shows "updated X ago", battery, and accuracy.
2. **Safe places** (home, school, tuition class) with arrive/leave alerts. Evaluated server-side.
3. **Arrive-by schedules**: "Nimal should reach Maths class by 3:30 pm on Tue/Thu", with a late alert.
4. **SOS**: a hold-to-trigger button, a lock-screen notification action, and a **voice safe-word** (on-device).
   - Sends push and SMS to all guardians.
   - The child's phone sends its own SMS fallback when it is offline.
5. **"I'm safe" check-in**.
6. Low-battery, went-offline, and speeding alerts.
7. Location history (trail). Retention depends on the plan and auto-deletes.
8. Co-guardian invite.
9. Child-device pairing with a single-use 8-character code (expires in 10 min).
10. Subscriptions via PayHere (LKR). Plan limits are enforced on the server.
11. Admin panel and CMS for the website's text, FAQ and pricing.

**Later (roadmap)**: school-van driver mode, crash/fall detection, wearables, Sinhala/Tamil TTS for alerts, WhatsApp alerts, and school (B2B) accounts.

## 2. Packages (default seed: fully editable in the admin panel)

| Plan | Price | Children | Places | History | SMS SOS | Voice SOS | Schedules | Co-guardians |
|---|---|---|---|---|---|---|---|---|
| **Free** | LKR 0 | 1 | 2 | 1 day | ✗ | ✗ | 1 | 0 |
| **Family** | LKR 490 / month | 3 | 10 | 30 days | ✓ | ✓ | 10 | 2 |
| **Premium** | LKR 990 / month | 6 | 30 | 90 days | ✓ | ✓ | 50 | 5 |

- Yearly plans get 2 months free.
- The **SOS push alert is free on every plan.** We never paywall the core safety feature.

## 3. Architecture

```
┌──────────────┐   HTTPS + App Check     ┌──────────────────────────┐
│ Flutter app  │ ──────────────────────▶ │ Firebase Auth            │
│ (parent/     │                         │ Cloud Firestore (rules)  │
│  child mode) │ ◀── FCM high-priority ──│ Cloud Functions (TS)     │
└──────────────┘                         │  • pairing / claims      │
┌──────────────┐                         │  • geofence engine       │
│ Next.js web  │ ──────────────────────▶ │  • SOS fan-out (FCM+SMS) │
│ site/dash/   │                         │  • schedules & heartbeat │
│ admin        │                         │  • PayHere checkout/IPN  │
└──────────────┘                         └──────────┬───────────────┘
                                                    │
                               PayHere (payments) ◀─┴─▶ SMS gateway (Notify.lk / Twilio)
```

**Why Firebase:**
- It is managed, scales to zero, and has first-class Flutter SDKs.
- Security rules are enforced at the database.
- App Check blocks scripted abuse.
- It is in the Google Cloud asia-south1 (Mumbai) region, close to Sri Lanka.

### Repository layout

```
/docs        research, plan, security, deployment
/firebase    firestore.rules, indexes, functions (TypeScript), rules tests
/mobile      Flutter app (parent + child modes)
/web         Next.js 14: marketing site + parent dashboard + admin panel
```

## 4. Data model (Firestore)

```
users/{uid}                     role, familyId, displayName, email, createdAt
users/{uid}/devices/{tokenId}   fcmToken, platform, updatedAt
families/{fid}                  name, ownerUid, planId, planStatus, planRenewsAt, limits{...}
families/{fid}/members/{uid}    role (parent|child), name, joinedAt
families/{fid}/children/{cid}   name, color, paired, pairedAt, settings{speedLimitKmh, lowBattery, guardMode}
families/{fid}/live/{cid}       lat, lng, accuracy, speed, heading, battery, charging, ts   ← only the child writes
families/{fid}/history/{id}     childId, lat, lng, ts, expireAt (TTL)                        ← functions only
families/{fid}/places/{pid}     name, type, lat, lng, radius, notifyEnter, notifyExit
families/{fid}/schedules/{sid}  childId, placeId, days[], arriveBy "HH:mm", tz
families/{fid}/geostate/{cid}   inside[placeIds], lastAlertAt                                ← functions only
families/{fid}/alerts/{aid}     type, childId, title, body, lat, lng, createdAt, status, resolvedBy
pairingCodes/{sha256(code)}     familyId, kind, childId, expiresAt, attempts, used           ← functions only
plans/{planId}                  public read; admin write
siteContent/{docId}             public read; admin write
payments/{orderId}              functions write; family parents read
auditLogs/{id}                  functions write; admin read
```

## 5. Key flows

**Parent sign-up**
1. The parent signs up with email (verified) or Google.
2. The parent calls the `createFamily` function.
3. The function sets the custom claims `{role:'parent', familyId}` and creates the family on the Free plan.

**Pair a child phone**
1. The parent taps "Add child" and calls `createPairingCode`. This returns `K7Q2-M9XD` (TTL 10 min).
2. On the child's phone, the child picks "This is my child's phone" and enters the code.
3. `redeemPairingCode` checks the hash, expiry, attempts and the plan limit.
4. It creates the child auth user `{role:'child', familyId, childId}` and returns a custom token.
5. The child app signs in and starts the location service.

**Location update**
1. The child app writes to `live/{cid}` about every 30 s while moving (distance filter 25 m), and sends a heartbeat every 5 min when still.
2. The `onLiveLocation` trigger then:
   - appends to history (with TTL);
   - evaluates geofences and fires enter/exit alerts (with a debounce);
   - checks speed and low battery.

**SOS**
1. The child holds the button for 2 s, says the safe-word, or taps the notification action.
2. `triggerSos` (callable, with App Check and a rate limit) creates the alert.
3. It sends FCM high-priority to every guardian device and SMS to guardians (on paid plans).
4. The guardian app opens a full-screen SOS page with the map, plus "Call child" and "Mark resolved".
5. If the child's phone is offline, the app sends an SMS with a maps link from the phone itself.

**Schedules**
- The `checkSchedules` job runs every 5 min.
- If the arrive-by time has passed today and the child hasn't entered the place, it sends a late alert, once per day.

**Heartbeat**
- The `checkHeartbeats` job runs every 15 min.
- If a child's last update is older than 45 min while guard mode is on, it sends an offline alert.

**Billing**
1. The parent picks a plan, and `createCheckout` returns signed PayHere params.
2. The PayHere JS/mobile SDK runs the payment.
3. `payhereNotify` verifies `md5sig`, upserts the payment, and updates the family plan and limits.

## 6. Delivery plan

| Phase | Scope |
|---|---|
| 0: Research and plan | This document, `RESEARCH.md`, `SECURITY.md` |
| 1: Backend | Rules, functions, tests (emulator) |
| 2: Mobile | Auth, family, pairing, child service, map, places, alerts, SOS, voice, billing |
| 3: Web | Marketing site, pricing (live from `plans`), parent dashboard, admin panel |
| 4: Hardening | Pen-test checklist, App Check enforcement, Play/App Store compliance, privacy policy |
| 5: Launch | Closed beta with 20 families, then public |

## 7. Store compliance checklist

- Android:
  - Prominent in-app disclosure **before** asking for background location.
  - The Play Console background-location declaration plus a demo video.
  - Foreground service type `location`.
- iOS:
  - `NSLocationAlwaysAndWhenInUseUsageDescription`, `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` strings.
  - Background mode `location`.
- Family policy: the child app is used **with parental consent on a device the parent manages**. It is not covert.
  - The child always sees that sharing is on (a persistent notification).
  - This is both an ethical choice and a store requirement. Covert spyware gets banned.
