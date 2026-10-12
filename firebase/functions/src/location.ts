import { onDocumentWritten } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import { familyRef, FieldValue, Timestamp } from "./lib/firebase";
import { evaluateGeofences, mapsLink, Place, toKmh } from "./lib/geo";
import { effectiveLimits } from "./lib/plans";
import { raiseAlert, smsGuardians, NOTIFYLK_API_KEY } from "./lib/notify";
import { DEFAULT_CHILD_SETTINGS } from "./pairing";

const HISTORY_MIN_INTERVAL_MS = 60 * 1000;
const SPEED_ALERT_COOLDOWN_MS = 15 * 60 * 1000;
const BATTERY_ALERT_COOLDOWN_MS = 6 * 3600 * 1000;
/** At this level the phone is about to die: send the last location before it goes dark. */
export const CRITICAL_BATTERY_PCT = 5;

interface Live {
  lat: number;
  lng: number;
  accuracy: number;
  speed?: number;
  battery?: number;
  charging?: boolean;
  ts: Timestamp;
  source?: string;
}

/**
 * Runs on every location write from a child device:
 *  1. appends to history (throttled, TTL by plan),
 *  2. evaluates safe-place enter/exit,
 *  3. raises speed and low-battery alerts (with cooldowns),
 *  4. at critical battery, sends the last location by push and SMS before the phone dies.
 */
export const onLiveLocation = onDocumentWritten(
  { document: "families/{fid}/live/{cid}", retry: false, secrets: [NOTIFYLK_API_KEY] },
  async (event) => {
    const after = event.data?.after.data() as Live | undefined;
    if (!after) return;
    const before = event.data?.before.data() as Live | undefined;
    const { fid, cid } = event.params;
    const fref = familyRef(fid);

    const [famSnap, childSnap, placesSnap, stateSnap] = await Promise.all([
      fref.get(),
      fref.collection("children").doc(cid).get(),
      fref.collection("places").get(),
      fref.collection("geostate").doc(cid).get(),
    ]);
    if (!childSnap.exists) return; // unpaired child, ignore
    const childName = (childSnap.get("name") as string) ?? "Your child";
    const settings = { ...DEFAULT_CHILD_SETTINGS, ...(childSnap.get("settings") ?? {}) };
    const limits = effectiveLimits(famSnap.get("limits"));
    const state = stateSnap.data() ?? {};
    const now = Date.now();
    const point = { lat: after.lat, lng: after.lng };
    const updates: Record<string, unknown> = { updatedAt: FieldValue.serverTimestamp() };

    // 1. History
    const lastHist = (state.lastHistoryAt as Timestamp | undefined)?.toMillis() ?? 0;
    if (now - lastHist >= HISTORY_MIN_INTERVAL_MS) {
      await fref.collection("history").add({
        childId: cid,
        ...point,
        accuracy: after.accuracy,
        speed: after.speed ?? null,
        battery: after.battery ?? null,
        ts: after.ts,
        expireAt: Timestamp.fromMillis(now + limits.historyDays * 86_400_000),
      });
      updates.lastHistoryAt = Timestamp.fromMillis(now);
    }

    // 2. Geofences
    const places: Place[] = placesSnap.docs.map((d) => ({ id: d.id, ...(d.data() as Omit<Place, "id">) }));
    const geo = evaluateGeofences((state.inside as string[]) ?? [], places, { ...point, accuracy: after.accuracy });
    updates.inside = geo.inside;
    const enteredToday: Record<string, string> = { ...(state.enteredToday ?? {}) };
    for (const p of geo.entered) {
      enteredToday[p.id] = new Date(now).toISOString();
      if (p.notifyEnter) {
        await raiseAlert(fid, {
          type: "enter", childId: cid, childName, placeId: p.id, ...point,
          title: `${childName} arrived at ${p.name}`,
          body: `Arrived ${timeLabel(now)}.`,
        });
      }
    }
    for (const p of geo.exited) {
      if (p.notifyExit) {
        await raiseAlert(fid, {
          type: "exit", childId: cid, childName, placeId: p.id, ...point,
          title: `${childName} left ${p.name}`,
          body: `Left ${timeLabel(now)}.`,
        });
      }
    }
    updates.enteredToday = enteredToday;

    // 3. Speed (only trust reasonably accurate GPS fixes)
    const kmh = toKmh(after.speed);
    const lastSpeedAlert = (state.lastSpeedAlertAt as Timestamp | undefined)?.toMillis() ?? 0;
    if (after.accuracy <= 50 && kmh > settings.speedLimitKmh && now - lastSpeedAlert > SPEED_ALERT_COOLDOWN_MS) {
      await raiseAlert(fid, {
        type: "speed", childId: cid, childName, ...point,
        title: `${childName} is moving fast`,
        body: `About ${Math.round(kmh)} km/h (limit ${settings.speedLimitKmh}). Check who they're travelling with.`,
      });
      updates.lastSpeedAlertAt = Timestamp.fromMillis(now);
    }

    // 4. Battery: alert once when crossing below the threshold, not on every update.
    const battery = after.battery;
    const prevBattery = before?.battery;
    const lastBatteryAlert = (state.lastBatteryAlertAt as Timestamp | undefined)?.toMillis() ?? 0;
    if (
      battery != null && !after.charging &&
      battery <= settings.lowBatteryPct &&
      (prevBattery == null || prevBattery > settings.lowBatteryPct || now - lastBatteryAlert > BATTERY_ALERT_COOLDOWN_MS) &&
      now - lastBatteryAlert > 30 * 60 * 1000
    ) {
      await raiseAlert(fid, {
        type: "battery", childId: cid, childName, ...point,
        title: `${childName}'s phone battery is low`,
        body: `${battery}% left. Location sharing will stop if it dies.`,
      });
      updates.lastBatteryAlertAt = Timestamp.fromMillis(now);
    }

    // 5. Critical battery: the phone will go dark soon, so hand guardians its last location.
    const lastCritical = (state.lastCriticalBatteryAt as Timestamp | undefined)?.toMillis() ?? 0;
    if (
      battery != null && !after.charging && battery <= CRITICAL_BATTERY_PCT &&
      now - lastCritical > BATTERY_ALERT_COOLDOWN_MS
    ) {
      await raiseAlert(fid, {
        type: "battery", childId: cid, childName, ...point,
        title: `${childName}'s phone is about to switch off`,
        body: `${battery}% battery. Last location saved (±${Math.round(after.accuracy)} m), open the map to see it.`,
      });
      if (limits.smsSos) {
        await smsGuardians(fid, `RAKAWALA: ${childName}'s phone battery is ${battery}% and may switch off. Last location: ${mapsLink(point)}`);
      }
      updates.lastCriticalBatteryAt = Timestamp.fromMillis(now);
    }

    // Reset the offline flag so the heartbeat job can alert again later.
    updates.offlineAlerted = false;
    await fref.collection("geostate").doc(cid).set(updates, { merge: true });
    logger.debug("location processed", { fid, cid, entered: geo.entered.length, exited: geo.exited.length });
  },
);

function timeLabel(ms: number): string {
  return new Intl.DateTimeFormat("en-LK", { timeZone: "Asia/Colombo", hour: "numeric", minute: "2-digit" }).format(ms);
}

