import { test } from "node:test";
import assert from "node:assert/strict";
import { controlsTurnedOff, newlyInstalled } from "../src/lib/apps";

test("new installs: detected against the previous report", () => {
  const before = [{ pkg: "com.whatsapp", name: "WhatsApp" }];
  const after = [...before, { pkg: "com.zhiliaoapp.musically", name: "TikTok" }];
  assert.deepEqual(newlyInstalled(before, after).map((a) => a.name), ["TikTok"]);
});

test("new installs: the first report isn't treated as 50 new apps", () => {
  assert.deepEqual(newlyInstalled(undefined, [{ pkg: "a", name: "A" }]), []);
  assert.deepEqual(newlyInstalled([], [{ pkg: "a", name: "A" }]), []);
});

test("tamper: alert only when controls go from on to off", () => {
  const on = { usageAccess: true, accessibility: true, platform: "android" };
  assert.equal(controlsTurnedOff(on, { ...on, accessibility: false }), true);
  assert.equal(controlsTurnedOff(on, { ...on, usageAccess: false }), true);
  assert.equal(controlsTurnedOff({ ...on, accessibility: false }, { ...on, accessibility: false }), false);
  assert.equal(controlsTurnedOff(undefined, { ...on, accessibility: false }), false);
  assert.equal(controlsTurnedOff(on, on), false);
});
