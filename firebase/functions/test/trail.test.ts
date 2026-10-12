import { test } from "node:test";
import assert from "node:assert/strict";
import { clampQuietMinutes, MAX_TRAIL_POINTS, MIN_POINT_GAP_MS, sanitizeTrail, TrailPoint } from "../src/lib/trail";

const NOW = Date.UTC(2026, 9, 12, 8, 0, 0);
const pt = (minutesAgo: number, over: Partial<TrailPoint> = {}): TrailPoint => ({
  lat: 6.9, lng: 79.86, accuracy: 20, ts: NOW - minutesAgo * 60_000, ...over,
});

test("trail: sorted oldest first", () => {
  const r = sanitizeTrail([pt(1), pt(10), pt(5)], NOW);
  assert.deepEqual(r.map((p) => (NOW - p.ts) / 60_000), [10, 5, 1]);
});

test("trail: rejects invalid coordinates and accuracy", () => {
  const r = sanitizeTrail([pt(3, { lat: 95 }), pt(2, { lng: NaN }), pt(1, { accuracy: -1 }), pt(0)], NOW);
  assert.equal(r.length, 1);
});

test("trail: drops points older than 72 h or far in the future", () => {
  const r = sanitizeTrail([pt(73 * 60), pt(-10), pt(-2), pt(1)], NOW);
  assert.equal(r.length, 2);
  assert.ok(r.every((p) => p.ts <= NOW), "future skew is clamped to now");
});

test("trail: thins points closer than 30 s, keeping the more accurate one", () => {
  const base = NOW - 600_000;
  const r = sanitizeTrail([
    { lat: 6.9, lng: 79.8, accuracy: 50, ts: base },
    { lat: 6.9, lng: 79.8, accuracy: 10, ts: base + 5_000 },
    { lat: 6.9, lng: 79.8, accuracy: 30, ts: base + MIN_POINT_GAP_MS + 6_000 },
  ], NOW);
  assert.equal(r.length, 2);
  assert.equal(r[0].accuracy, 10);
});

test("trail: caps a huge upload to the most recent points", () => {
  const many = Array.from({ length: 2000 }, (_, i) => pt(i));
  const r = sanitizeTrail(many, NOW);
  assert.equal(r.length, MAX_TRAIL_POINTS);
  assert.equal(r[r.length - 1].ts, NOW);
});

test("quiet window minutes are clamped to 15 min .. 12 h", () => {
  assert.equal(clampQuietMinutes(5), 15);
  assert.equal(clampQuietMinutes(90), 90);
  assert.equal(clampQuietMinutes(10_000), 720);
  assert.equal(clampQuietMinutes(NaN), 0);
});
