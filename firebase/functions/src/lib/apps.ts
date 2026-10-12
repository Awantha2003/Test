/** App-control helpers. Pure, no Firebase imports. */

export interface InstalledApp {
  pkg: string;
  name: string;
}

/** Apps present now that weren't in the previous report (ignores the very first report). */
export function newlyInstalled(before: InstalledApp[] | undefined, after: InstalledApp[] | undefined): InstalledApp[] {
  if (!before || before.length === 0 || !after) return [];
  const known = new Set(before.map((a) => a.pkg));
  return after.filter((a) => a && typeof a.pkg === "string" && !known.has(a.pkg));
}

export interface ControlsState {
  usageAccess?: boolean;
  accessibility?: boolean;
  platform?: string;
}

/** True when app blocking was working and has just been switched off on the phone. */
export function controlsTurnedOff(before: ControlsState | undefined, after: ControlsState | undefined): boolean {
  if (!before || !after || after.platform === "ios") return false;
  const was = before.accessibility === true && before.usageAccess === true;
  const now = after.accessibility === true && after.usageAccess === true;
  return was && !now;
}
