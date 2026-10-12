import { test } from "node:test";
import assert from "node:assert/strict";
import { tamperEvents } from "../src/lib/device";

const ok = { locationPermission: "always", locationService: true, uninstallProtection: true, platform: "android" } as const;

test("tamper: each downgrade raises exactly one event", () => {
  assert.deepEqual(tamperEvents(ok, { ...ok, locationPermission: "whileInUse" }).map((e) => e.key), ["locationPermission"]);
  assert.deepEqual(tamperEvents(ok, { ...ok, locationService: false }).map((e) => e.key), ["locationService"]);
  assert.deepEqual(tamperEvents(ok, { ...ok, uninstallProtection: false }).map((e) => e.key), ["uninstallProtection"]);
  assert.equal(tamperEvents(ok, { ...ok, locationPermission: "denied", locationService: false, uninstallProtection: false }).length, 3);
});

test("tamper: no alerts for first report, unchanged state, or improvements", () => {
  assert.deepEqual(tamperEvents(undefined, ok), []);
  assert.deepEqual(tamperEvents(ok, ok), []);
  assert.deepEqual(tamperEvents({ ...ok, locationService: false }, ok), []);
  assert.deepEqual(tamperEvents({ ...ok, uninstallProtection: null }, { ...ok, uninstallProtection: null }), [], "iPhone has no uninstall guard");
});

test("tamper: messages name the child", () => {
  const [e] = tamperEvents(ok, { ...ok, uninstallProtection: false });
  assert.match(e.title("Nimal"), /Nimal's phone/);
});
