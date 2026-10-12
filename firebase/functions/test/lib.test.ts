import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { distanceMeters, evaluateGeofences, Place, toKmh, EXIT_HYSTERESIS_M } from "../src/lib/geo";
import { checkoutHash, formatAmount, verifyNotify, PayHereNotify } from "../src/lib/payhere";
import { addPeriod, effectiveLimits, FREE_LIMITS, withinLimit, DEFAULT_PLANS } from "../src/lib/plans";
import { CODE_ALPHABET, CODE_LENGTH, formatCode, generateCode, hashCode, normalizeCode } from "../src/lib/codes";
import { isLate, localTime, parseHHmm } from "../src/lib/schedule";

const md5U = (s: string) => createHash("md5").update(s).digest("hex").toUpperCase();

// ---------- geo ----------

test("distance: Colombo Fort → Galle Face ≈ 1.3 km", () => {
  const d = distanceMeters({ lat: 6.9344, lng: 79.8428 }, { lat: 6.9227, lng: 79.8450 });
  assert.ok(d > 1200 && d < 1450, `got ${d}`);
});

const school: Place = { id: "school", name: "School", lat: 6.9, lng: 79.86, radius: 100, notifyEnter: true, notifyExit: true };
const offsetNorth = (m: number) => ({ lat: school.lat + m / 111_320, lng: school.lng });

test("geofence: enter when inside radius", () => {
  const r = evaluateGeofences([], [school], { ...offsetNorth(50), accuracy: 10 });
  assert.deepEqual(r.inside, ["school"]);
  assert.equal(r.entered.length, 1);
});

test("geofence: no exit inside the hysteresis band (no flapping)", () => {
  const r = evaluateGeofences(["school"], [school], { ...offsetNorth(100 + EXIT_HYSTERESIS_M - 5), accuracy: 10 });
  assert.deepEqual(r.inside, ["school"]);
  assert.equal(r.exited.length, 0);
});

test("geofence: exit beyond radius + hysteresis", () => {
  const r = evaluateGeofences(["school"], [school], { ...offsetNorth(200), accuracy: 10 });
  assert.deepEqual(r.inside, []);
  assert.equal(r.exited.length, 1);
});

test("geofence: inaccurate fixes never change state", () => {
  const r = evaluateGeofences(["school"], [school], { ...offsetNorth(5000), accuracy: 900 });
  assert.deepEqual(r.inside, ["school"]);
  assert.equal(r.exited.length, 0);
});

test("geofence: deleted places drop out silently", () => {
  const r = evaluateGeofences(["gone", "school"], [school], { ...offsetNorth(10), accuracy: 10 });
  assert.deepEqual(r.inside, ["school"]);
  assert.equal(r.exited.length, 0);
});

test("speed conversion handles unknown speed", () => {
  assert.equal(toKmh(-1), 0);
  assert.equal(toKmh(null), 0);
  assert.equal(Math.round(toKmh(20)), 72);
});

// ---------- PayHere ----------

test("payhere: amount formatting", () => {
  assert.equal(formatAmount(490), "490.00");
  assert.equal(formatAmount(1234.5), "1234.50");
  assert.throws(() => formatAmount(-1));
});

test("payhere: checkout hash matches the documented formula", () => {
  const expected = md5U("1211149" + "ORDER1" + "490.00" + "LKR" + md5U("secret"));
  assert.equal(checkoutHash("1211149", "ORDER1", 490, "LKR", "secret"), expected);
});

const notify = (over: Partial<PayHereNotify> = {}): PayHereNotify => {
  const n = { merchant_id: "1211149", order_id: "ORDER1", payhere_amount: "490.00", payhere_currency: "LKR", status_code: "2", md5sig: "", ...over };
  n.md5sig = over.md5sig ?? md5U(n.merchant_id + n.order_id + n.payhere_amount + n.payhere_currency + n.status_code + md5U("secret"));
  return n;
};

test("payhere: valid notification verifies", () => {
  assert.equal(verifyNotify(notify(), "1211149", "secret"), true);
});

test("payhere: tampered amount, status, merchant or secret is rejected", () => {
  const good = notify();
  assert.equal(verifyNotify({ ...good, payhere_amount: "990.00" }, "1211149", "secret"), false);
  assert.equal(verifyNotify({ ...good, status_code: "-2" }, "1211149", "secret"), false);
  assert.equal(verifyNotify(good, "9999999", "secret"), false);
  assert.equal(verifyNotify(good, "1211149", "wrong"), false);
  assert.equal(verifyNotify({ ...good, md5sig: "short" }, "1211149", "secret"), false);
  assert.equal(verifyNotify(undefined as unknown as PayHereNotify, "1211149", "secret"), false);
});

// ---------- plans ----------

test("plans: limits enforced and missing keys fall back to Free", () => {
  assert.equal(withinLimit(FREE_LIMITS, "maxChildren", 0), true);
  assert.equal(withinLimit(FREE_LIMITS, "maxChildren", 1), false);
  assert.equal(withinLimit(undefined, "maxPlaces", 1), true);
  assert.equal(withinLimit(undefined, "maxPlaces", 2), false);
  assert.equal(effectiveLimits({ maxChildren: 3 }).maxPlaces, FREE_LIMITS.maxPlaces);
});

test("plans: SOS push is never paywalled and paid plans are strictly better", () => {
  const free = DEFAULT_PLANS.find((p) => p.id === "free")!;
  assert.ok(free.features.some((f) => f.includes("SOS")));
  for (const p of DEFAULT_PLANS.filter((p) => p.interval !== "free")) {
    assert.ok(p.limits.maxChildren >= free.limits.maxChildren);
    assert.ok(p.priceLkr > 0);
  }
});

test("plans: addPeriod", () => {
  const d = new Date(Date.UTC(2026, 0, 15));
  assert.equal(addPeriod(d, "month").toISOString().slice(0, 10), "2026-02-15");
  assert.equal(addPeriod(d, "year").toISOString().slice(0, 10), "2027-01-15");
});

// ---------- codes ----------

test("codes: generated codes use the unambiguous alphabet", () => {
  for (let i = 0; i < 200; i++) {
    const c = generateCode();
    assert.equal(c.length, CODE_LENGTH);
    for (const ch of c) assert.ok(CODE_ALPHABET.includes(ch));
  }
});

test("codes: normalisation and formatting round-trip", () => {
  assert.equal(normalizeCode(" k7q2-m9xd "), "K7Q2M9XD");
  assert.equal(normalizeCode(formatCode("K7Q2M9XD")), "K7Q2M9XD");
  assert.equal(normalizeCode("K7Q2M9X0"), null); // 0 not in alphabet
  assert.equal(normalizeCode("SHORT"), null);
  assert.notEqual(hashCode("K7Q2M9XD"), "K7Q2M9XD");
  assert.equal(hashCode("K7Q2M9XD").length, 64);
});

// ---------- schedules ----------

test("schedule: Colombo local time (UTC+5:30)", () => {
  const t = localTime(new Date("2026-10-13T09:45:00Z"), "Asia/Colombo"); // Tue 15:15 local
  assert.equal(t.day, "tue");
  assert.equal(t.minutes, 15 * 60 + 15);
  assert.equal(t.dateKey, "2026-10-13");
});

test("schedule: late only after grace, only on scheduled days, within window", () => {
  const s = { days: ["tue", "thu"], arriveBy: "15:00", graceMin: 10 };
  const at = (iso: string) => localTime(new Date(iso), "Asia/Colombo");
  assert.equal(isLate(s, at("2026-10-13T09:35:00Z")), false); // 15:05, within grace
  assert.equal(isLate(s, at("2026-10-13T09:45:00Z")), true); // 15:15
  assert.equal(isLate(s, at("2026-10-14T09:45:00Z")), false); // Wednesday
  assert.equal(isLate(s, at("2026-10-13T17:00:00Z")), false); // 22:30, outside window
  assert.equal(parseHHmm("24:00"), null);
});
