/** Child-device protection state and tamper detection. Pure, no Firebase imports. */

export type LocationPermission = "always" | "whileInUse" | "denied";

export interface DeviceStatus {
  locationPermission?: LocationPermission;
  locationService?: boolean;
  /** null on iPhone (no equivalent). */
  uninstallProtection?: boolean | null;
  platform?: "android" | "ios";
}

export interface TamperEvent {
  key: "locationPermission" | "locationService" | "uninstallProtection";
  title: (name: string) => string;
  body: string;
}

/**
 * What protection the child's phone just lost. Only downgrades count (a first report,
 * or something being switched back on, raises nothing).
 */
export function tamperEvents(before: DeviceStatus | undefined, after: DeviceStatus | undefined): TamperEvent[] {
  if (!before || !after) return [];
  const out: TamperEvent[] = [];
  if (before.locationPermission === "always" && after.locationPermission && after.locationPermission !== "always") {
    out.push({
      key: "locationPermission",
      title: (n) => `Location access was reduced on ${n}'s phone`,
      body: after.locationPermission === "denied"
        ? "Location is now blocked for Rakawala, so you can't see where they are."
        : "Rakawala can now see location only while the app is open, not in the background.",
    });
  }
  if (before.locationService === true && after.locationService === false) {
    out.push({
      key: "locationService",
      title: (n) => `Location (GPS) was switched off on ${n}'s phone`,
      body: "You'll see the last known location until it's switched back on.",
    });
  }
  if (before.uninstallProtection === true && after.uninstallProtection === false) {
    out.push({
      key: "uninstallProtection",
      title: (n) => `Uninstall protection was turned off on ${n}'s phone`,
      body: "Rakawala can now be removed from the phone. Check in with them.",
    });
  }
  return out;
}
