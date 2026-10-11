# Rakawala: Child Safety SaaS (රැකවල)

> Live location, tuition-class arrival alerts and one-tap/voice SOS for Sri Lankan families.
> The project has a Flutter app (parent and child modes), a website, a parent web dashboard and an admin panel, all on a hardened Firebase backend.

## සිංහලෙන් කෙටියෙන් (Summary in Sinhala)

- **Parent app**:
  - ළමයි ඉන්න තැන live map එකේ.
  - Class / school ගියාද, ආවාද කියලා alert.
  - "3:30ට class එකට යන්න ඕනේ" වගේ schedule. පරක්කු වුණොත් alert.
  - Battery අඩු වුණොත්, phone එක off වුණොත්, වේගයෙන් යනවා නම් alert.
- **Child app**:
  - ලොකු **SOS button** එක (තත්පර 2ක් ඔබාගෙන ඉන්න).
  - **Secret voice word** එක කිව්වොත් auto SOS.
  - "I'm safe" button එක.
  - Internet නැත්නම් SMS එකකින් location එක යවනවා.
- **Website**: landing page, pricing, parent dashboard (live map).
- **Admin panel**: users, families, **packages (මිල ගණන් / limits)**, payments, website content edit කරන්න, audit log.
- **Payments**: PayHere (LKR) monthly/yearly subscriptions.
- **Security**: cyber-security threat model එකක් (STRIDE) අනුව design කරලා තියෙන්නේ. `docs/SECURITY.md` බලන්න.

## Repository

| Path | What |
|---|---|
| `docs/RESEARCH.md` | Real-world risks in Sri Lanka, competitor scan, technical limits |
| `docs/PLAN.md` | A-to-Z product and engineering plan, data model, flows, packages |
| `docs/SECURITY.md` | Threat model (STRIDE), controls, pre-release security checklist |
| `docs/DEPLOYMENT.md` | Step-by-step go-live guide |
| `firebase/` | Firestore rules + rules tests, Cloud Functions (TypeScript) + unit tests |
| `mobile/` | Flutter app (Android/iOS): parent and child modes |
| `web/` | Next.js website, parent dashboard and admin panel |

## Quality gates (all passing)

| Check | Result |
|---|---|
| Cloud Functions typecheck + unit tests (geofence, PayHere signatures, plans, codes, schedules) | 18/18 ✅ |
| Firestore security-rules tests on the emulator (tenancy, tampering, admin MFA, privacy) | 21/21 ✅ |
| Flutter `analyze` | no issues ✅ |
| Flutter tests (router guards, SOS hold, voice word, rule-compatible payloads) | 18/18 ✅ |
| Web typecheck + tests + production build | ✅ |
| `npm audit` (high) on functions and web | 0 ✅ |

## Quick start

```bash
# Backend tests
cd firebase/functions && npm ci && npm test
cd .. && npm ci && npm run test:rules

# Website
cd web && npm ci && npm run dev

# Mobile
cd mobile && flutter pub get && flutter test && flutter run
```

For a real deployment (Firebase project, PayHere, SMS, store listings), follow **`docs/DEPLOYMENT.md`**.
