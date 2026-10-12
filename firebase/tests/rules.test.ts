/**
 * Firestore security rules tests. Run with: npm run test:rules (starts the emulator).
 * These encode the threat model in docs/SECURITY.md.
 */
import { after, before, beforeEach, test } from "node:test";
import { readFileSync } from "node:fs";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, updateDoc, serverTimestamp, collection, getDocs, deleteDoc, query, where } from "firebase/firestore";

let env: RulesTestEnvironment;

const FAM_A = "famA";
const FAM_B = "famB";

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-rakawala",
    firestore: { rules: readFileSync("firestore.rules", "utf8") },
  });
});

after(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const fid of [FAM_A, FAM_B]) {
      await setDoc(doc(db, `families/${fid}`), { name: fid, ownerUid: `${fid}-mom`, planId: "free", limits: { maxChildren: 1 } });
      await setDoc(doc(db, `families/${fid}/members/${fid}-mom`), { role: "parent", name: "Mom", phone: null, smsAlerts: true });
      await setDoc(doc(db, `families/${fid}/children/${fid}-kid`), { name: "Kid", color: "#2563EB", settings: { speedLimitKmh: 70 } });
      await setDoc(doc(db, `families/${fid}/live/${fid}-kid`), { lat: 6.9, lng: 79.8, accuracy: 10, ts: new Date() });
      await setDoc(doc(db, `families/${fid}/places/home`), { name: "Home", lat: 6.9, lng: 79.8, radius: 100 });
      await setDoc(doc(db, `families/${fid}/history/h1`), { childId: `${fid}-kid`, lat: 6.9, lng: 79.8 });
      await setDoc(doc(db, `families/${fid}/alerts/a1`), { type: "sos", status: "open" });
    }
    await setDoc(doc(db, "users/famA-mom"), { role: "parent", familyId: FAM_A, displayName: "Mom" });
    await setDoc(doc(db, `families/${FAM_B}`), { name: FAM_B, ownerUid: `${FAM_B}-mom`, planId: "family_month", limits: { maxChildren: 3, appControls: true } });
    await setDoc(doc(db, "plans/free"), { name: "Free", priceLkr: 0 });
    await setDoc(doc(db, "pairingCodes/abc"), { familyId: FAM_A, used: false });
    await setDoc(doc(db, "payments/ORDER1"), { familyId: FAM_A, status: "paid" });
  });
});

const parent = (fid = FAM_A) => env.authenticatedContext(`${fid}-mom`, { role: "parent", familyId: fid }).firestore();
const child = (fid = FAM_A) => env.authenticatedContext(`${fid}-kid`, { role: "child", familyId: fid }).firestore();
const admin = () =>
  env.authenticatedContext("admin1", { admin: true, firebase: { sign_in_provider: "password", sign_in_second_factor: "totp" } }).firestore();
const adminNoMfa = () => env.authenticatedContext("admin2", { admin: true, firebase: { sign_in_provider: "password" } }).firestore();
const anon = () => env.unauthenticatedContext().firestore();
const stranger = () => env.authenticatedContext("eve", {}).firestore();

// ---------- tenancy ----------

test("parent reads own family's live location, places, history, alerts", async () => {
  const db = parent();
  await assertSucceeds(getDoc(doc(db, `families/${FAM_A}/live/${FAM_A}-kid`)));
  await assertSucceeds(getDocs(collection(db, `families/${FAM_A}/places`)));
  await assertSucceeds(getDocs(collection(db, `families/${FAM_A}/history`)));
  await assertSucceeds(getDocs(collection(db, `families/${FAM_A}/alerts`)));
});

test("parent of family A cannot read anything in family B", async () => {
  const db = parent(FAM_A);
  await assertFails(getDoc(doc(db, `families/${FAM_B}`)));
  await assertFails(getDoc(doc(db, `families/${FAM_B}/live/${FAM_B}-kid`)));
  await assertFails(getDocs(collection(db, `families/${FAM_B}/history`)));
  await assertFails(getDocs(collection(db, `families/${FAM_B}/members`)));
});

test("strangers and anonymous users see nothing private", async () => {
  for (const db of [stranger(), anon()]) {
    await assertFails(getDoc(doc(db, `families/${FAM_A}`)));
    await assertFails(getDoc(doc(db, `families/${FAM_A}/live/${FAM_A}-kid`)));
    await assertFails(getDoc(doc(db, "users/famA-mom")));
  }
});

test("a user cannot claim a family by forging nothing but a uid", async () => {
  const db = env.authenticatedContext(`${FAM_A}-mom`, {}).firestore(); // right uid, no claims
  await assertFails(getDoc(doc(db, `families/${FAM_A}/live/${FAM_A}-kid`)));
});

// ---------- child device ----------

test("child writes only its own live location with a valid schema", async () => {
  const db = child();
  const ref = doc(db, `families/${FAM_A}/live/${FAM_A}-kid`);
  await assertSucceeds(setDoc(ref, { lat: 6.91, lng: 79.85, accuracy: 12, speed: 1.2, heading: 90, battery: 80, charging: false, ts: serverTimestamp(), source: "gps" }));
});

test("child live write rejects bad data", async () => {
  const ref = doc(child(), `families/${FAM_A}/live/${FAM_A}-kid`);
  await assertFails(setDoc(ref, { lat: 200, lng: 79.85, accuracy: 12, ts: serverTimestamp() })); // out of range
  await assertFails(setDoc(ref, { lat: 6.9, lng: 79.85, accuracy: 12, ts: new Date(2020, 1, 1) })); // spoofed time
  await assertFails(setDoc(ref, { lat: 6.9, lng: 79.85, accuracy: 12, ts: serverTimestamp(), isAdmin: true })); // extra key
  await assertFails(setDoc(ref, { lat: 6.9, lng: 79.85, accuracy: 12, ts: serverTimestamp(), source: "fake" }));
});

test("child cannot write another child's location or another family's", async () => {
  const db = child();
  await assertFails(setDoc(doc(db, `families/${FAM_A}/live/someone-else`), { lat: 1, lng: 1, accuracy: 1, ts: serverTimestamp() }));
  await assertFails(setDoc(doc(db, `families/${FAM_B}/live/${FAM_A}-kid`), { lat: 1, lng: 1, accuracy: 1, ts: serverTimestamp() }));
});

test("parent cannot fake a child's location", async () => {
  await assertFails(setDoc(doc(parent(), `families/${FAM_A}/live/${FAM_A}-kid`), { lat: 1, lng: 1, accuracy: 1, ts: serverTimestamp() }));
});

test("child cannot read places, history, alerts, or other children", async () => {
  const db = child();
  await assertFails(getDocs(collection(db, `families/${FAM_A}/places`)));
  await assertFails(getDocs(collection(db, `families/${FAM_A}/history`)));
  await assertFails(getDocs(collection(db, `families/${FAM_A}/alerts`)));
  await assertFails(getDoc(doc(db, `families/${FAM_A}/children/other`)));
  await assertSucceeds(getDoc(doc(db, `families/${FAM_A}/children/${FAM_A}-kid`)));
});

test("child cannot rename itself or change its settings", async () => {
  await assertFails(updateDoc(doc(child(), `families/${FAM_A}/children/${FAM_A}-kid`), { name: "Hacker" }));
});

// ---------- tampering with billing / limits ----------

test("parent cannot upgrade their own plan or limits", async () => {
  const ref = doc(parent(), `families/${FAM_A}`);
  await assertFails(updateDoc(ref, { planId: "premium_month" }));
  await assertFails(updateDoc(ref, { limits: { maxChildren: 99 } }));
  await assertFails(updateDoc(ref, { ownerUid: "eve" }));
  await assertSucceeds(updateDoc(ref, { name: "The Perera Family" }));
});

test("parent cannot write places, alerts, history or payments directly (functions only)", async () => {
  const db = parent();
  await assertFails(setDoc(doc(db, `families/${FAM_A}/places/new`), { name: "X", lat: 1, lng: 1, radius: 100 }));
  await assertFails(updateDoc(doc(db, `families/${FAM_A}/alerts/a1`), { status: "resolved" }));
  await assertFails(deleteDoc(doc(db, `families/${FAM_A}/history/h1`)));
  await assertFails(setDoc(doc(db, "payments/FAKE"), { familyId: FAM_A, status: "paid" }));
});

test("parent can edit child settings within allowed ranges only", async () => {
  const ref = doc(parent(), `families/${FAM_A}/children/${FAM_A}-kid`);
  await assertSucceeds(updateDoc(ref, { settings: { speedLimitKmh: 60, guardMode: true, voiceSos: true, safeWord: "mango" } }));
  await assertFails(updateDoc(ref, { settings: { speedLimitKmh: 5 } }));
  await assertFails(updateDoc(ref, { settings: { evil: true } }));
  await assertFails(updateDoc(ref, { paired: false }));
});

test("members: parent edits only own name/phone", async () => {
  const db = parent();
  await assertSucceeds(updateDoc(doc(db, `families/${FAM_A}/members/${FAM_A}-mom`), { phone: "+94771234567" }));
  await assertFails(updateDoc(doc(db, `families/${FAM_A}/members/${FAM_A}-mom`), { role: "admin" }));
  await assertFails(updateDoc(doc(db, `families/${FAM_A}/members/${FAM_A}-mom`), { phone: "not-a-phone" }));
});

test("users cannot grant themselves roles or families", async () => {
  const ref = doc(parent(), "users/famA-mom");
  await assertSucceeds(updateDoc(ref, { displayName: "Amma" }));
  await assertFails(updateDoc(ref, { familyId: FAM_B }));
  await assertFails(updateDoc(ref, { role: "admin" }));
});

test("payments readable only by own family", async () => {
  await assertSucceeds(getDoc(doc(parent(FAM_A), "payments/ORDER1")));
  await assertFails(getDoc(doc(parent(FAM_B), "payments/ORDER1")));
  await assertSucceeds(getDocs(query(collection(parent(FAM_A), "payments"), where("familyId", "==", FAM_A))));
  await assertFails(getDocs(collection(parent(FAM_A), "payments")));
});

test("pairing codes and rate limits are never client-readable", async () => {
  await assertFails(getDoc(doc(parent(), "pairingCodes/abc")));
  await assertFails(getDoc(doc(admin(), "pairingCodes/abc")));
  await assertFails(getDocs(collection(anon(), "rateLimits")));
});

// ---------- admin ----------

test("admin manages plans and site content; public can read them", async () => {
  const plan = { name: "Family", priceLkr: 490, interval: "month", limits: {}, features: [], active: true, order: 1 };
  await assertSucceeds(setDoc(doc(admin(), "plans/family_month"), plan));
  await assertFails(setDoc(doc(parent(), "plans/family_month"), { ...plan, priceLkr: 0 }));
  await assertSucceeds(getDoc(doc(anon(), "plans/free")));
  await assertSucceeds(setDoc(doc(admin(), "siteContent/home"), { heroTitle: "Hi" }));
  await assertFails(setDoc(doc(parent(), "siteContent/home"), { heroTitle: "Hacked" }));
  await assertSucceeds(getDoc(doc(anon(), "siteContent/home")));
});

test("admin without a second factor is treated as a normal user", async () => {
  const db = adminNoMfa();
  await assertFails(getDoc(doc(db, `families/${FAM_A}`)));
  await assertFails(getDoc(doc(db, "users/famA-mom")));
  await assertFails(setDoc(doc(db, "siteContent/home"), { heroTitle: "Hacked" }));
  await assertFails(getDocs(collection(db, "auditLogs")));
});

test("admin can see accounts but NOT children's live location or history", async () => {
  const db = admin();
  await assertSucceeds(getDoc(doc(db, `families/${FAM_A}`)));
  await assertSucceeds(getDoc(doc(db, "users/famA-mom")));
  await assertFails(getDoc(doc(db, `families/${FAM_A}/live/${FAM_A}-kid`)));
  await assertFails(getDocs(collection(db, `families/${FAM_A}/history`)));
  await assertFails(getDocs(collection(db, `families/${FAM_A}/places`)));
});

test("device token registration is scoped to the owner", async () => {
  const mine = doc(parent(), "users/famA-mom/devices/d1");
  await assertSucceeds(setDoc(mine, { token: "fcm-token", platform: "android", updatedAt: serverTimestamp() }));
  await assertFails(setDoc(doc(parent(FAM_B), "users/famA-mom/devices/d2"), { token: "x", platform: "android", updatedAt: serverTimestamp() }));
});

// ---------- app controls ----------

const rules = (uid: string) => ({
  apps: { "com.zhiliaoapp.musically": { mode: "block" } },
  schedules: [{ id: "school", label: "School time", days: ["mon", "tue"], start: "07:30", end: "13:30", active: true }],
  dailyLimitMin: 120,
  updatedAt: serverTimestamp(),
  updatedBy: uid,
});

test("app rules: paid-plan guardian can set them, child can read them", async () => {
  await assertSucceeds(setDoc(doc(parent(FAM_B), `families/${FAM_B}/appRules/${FAM_B}-kid`), rules(`${FAM_B}-mom`)));
  await assertSucceeds(getDoc(doc(child(FAM_B), `families/${FAM_B}/appRules/${FAM_B}-kid`)));
});

test("app rules: blocked on the Free plan, for children, and with bad schedules", async () => {
  await assertFails(setDoc(doc(parent(FAM_A), `families/${FAM_A}/appRules/${FAM_A}-kid`), rules(`${FAM_A}-mom`)));
  await assertFails(setDoc(doc(child(FAM_B), `families/${FAM_B}/appRules/${FAM_B}-kid`), rules(`${FAM_B}-kid`)));
  const bad = { ...rules(`${FAM_B}-mom`), schedules: [{ id: "x", label: "X", days: [], start: "25:00", end: "07:00", active: true }] };
  await assertFails(setDoc(doc(parent(FAM_B), `families/${FAM_B}/appRules/${FAM_B}-kid`), bad));
  await assertFails(setDoc(doc(parent(FAM_B), `families/${FAM_B}/appRules/nobody`), rules(`${FAM_B}-mom`)));
});

test("app usage: only the child phone reports it, only parents read it", async () => {
  const usage = { date: "2026-10-12", apps: { "com.whatsapp": { name: "WhatsApp", minutes: 42 } }, totalMin: 42, installed: [], controls: { usageAccess: true, accessibility: true, platform: "android" }, ts: serverTimestamp() };
  await assertSucceeds(setDoc(doc(child(), `families/${FAM_A}/appUsage/${FAM_A}-kid`), usage));
  await assertFails(setDoc(doc(child(), `families/${FAM_A}/appUsage/other`), usage));
  await assertFails(setDoc(doc(parent(), `families/${FAM_A}/appUsage/${FAM_A}-kid`), usage));
  await assertSucceeds(getDoc(doc(parent(), `families/${FAM_A}/appUsage/${FAM_A}-kid`)));
  await assertFails(getDoc(doc(parent(FAM_B), `families/${FAM_A}/appUsage/${FAM_A}-kid`)));
});

test("parents can't switch on live mode directly (server-only, rate-limited)", async () => {
  await assertFails(updateDoc(doc(parent(), `families/${FAM_A}/children/${FAM_A}-kid`), { liveUntil: new Date(2030, 1, 1) }));
});

// ---------- only a guardian can disconnect a child ----------

test("child phone can't remove itself, its membership or the family", async () => {
  const db = child();
  await assertFails(deleteDoc(doc(db, `families/${FAM_A}/children/${FAM_A}-kid`)));
  await assertFails(deleteDoc(doc(db, `families/${FAM_A}/members/${FAM_A}-kid`)));
  await assertFails(deleteDoc(doc(db, `families/${FAM_A}/live/${FAM_A}-kid`)));
  await assertFails(deleteDoc(doc(db, `families/${FAM_A}`)));
  await assertFails(setDoc(doc(db, `families/${FAM_A}/members/${FAM_A}-kid`), { role: "parent", name: "Kid" }));
});

test("device status: written only by the child phone, schema-checked, read by guardians", async () => {
  const status = { locationPermission: "always", locationService: true, uninstallProtection: true, platform: "android", appVersion: "1.0.0", ts: serverTimestamp() };
  await assertSucceeds(setDoc(doc(child(), `families/${FAM_A}/deviceStatus/${FAM_A}-kid`), status));
  await assertFails(setDoc(doc(child(), `families/${FAM_A}/deviceStatus/${FAM_A}-kid`), { ...status, locationPermission: "sometimes" }));
  await assertFails(setDoc(doc(parent(), `families/${FAM_A}/deviceStatus/${FAM_A}-kid`), status));
  await assertSucceeds(getDoc(doc(parent(), `families/${FAM_A}/deviceStatus/${FAM_A}-kid`)));
  await assertFails(getDoc(doc(parent(FAM_B), `families/${FAM_A}/deviceStatus/${FAM_A}-kid`)));
});
