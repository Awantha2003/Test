import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import { db, familyRef, Timestamp } from "./lib/firebase";
import { isLate, localTime } from "./lib/schedule";
import { raiseAlert } from "./lib/notify";
import { FREE_LIMITS } from "./lib/plans";
import { DEFAULT_CHILD_SETTINGS } from "./pairing";
import { audit } from "./lib/audit";

/** Every 5 min: "should have arrived at class by now" alerts. Once per schedule per day. */
export const checkSchedules = onSchedule({ schedule: "every 5 minutes", timeZone: "Asia/Colombo" }, async () => {
  const now = new Date();
  const snap = await db.collectionGroup("schedules").where("active", "==", true).get();
  for (const doc of snap.docs) {
    const s = doc.data() as {
      familyId: string; childId: string; placeId: string; label: string;
      days: string[]; arriveBy: string; graceMin?: number; tz?: string; lastLateAlert?: string;
    };
    const local = localTime(now, s.tz ?? "Asia/Colombo");
    if (s.lastLateAlert === local.dateKey || !isLate(s, local)) continue;

    const fref = familyRef(s.familyId);
    const [state, child, place] = await Promise.all([
      fref.collection("geostate").doc(s.childId).get(),
      fref.collection("children").doc(s.childId).get(),
      fref.collection("places").doc(s.placeId).get(),
    ]);
    if (!child.exists || !place.exists) continue;

    // Arrived today? (entered timestamp falls on today's local date, or is inside right now)
    const enteredIso = (state.get("enteredToday") ?? {})[s.placeId] as string | undefined;
    const enteredToday = enteredIso && localTime(new Date(enteredIso), s.tz ?? "Asia/Colombo").dateKey === local.dateKey;
    const insideNow = ((state.get("inside") as string[] | undefined) ?? []).includes(s.placeId);
    if (enteredToday || insideNow) continue;

    const childName = child.get("name") as string;
    await raiseAlert(s.familyId, {
      type: "late",
      childId: s.childId,
      childName,
      placeId: s.placeId,
      title: `${childName} hasn't reached ${place.get("name")}`,
      body: `${s.label}: expected by ${s.arriveBy}. Open the map to check.`,
    });
    await doc.ref.update({ lastLateAlert: local.dateKey });
  }
});

/** Every 15 min: alert when a child's phone stops reporting (switched off, dead, or taken). */
export const checkHeartbeats = onSchedule({ schedule: "every 15 minutes", timeZone: "Asia/Colombo" }, async () => {
  const now = Date.now();
  // Children who haven't reported for at least the minimum threshold (15 min).
  const stale = await db.collectionGroup("live").where("ts", "<", Timestamp.fromMillis(now - 15 * 60_000)).get();
  for (const live of stale.docs) {
    const fref = live.ref.parent.parent!;
    const cid = live.id;
    const [child, state] = await Promise.all([
      fref.collection("children").doc(cid).get(),
      fref.collection("geostate").doc(cid).get(),
    ]);
    if (!child.exists || state.get("offlineAlerted") === true) continue;
    // A planned no-signal window (train, rural trip) silences the alert until it ends.
    const quietUntil = (state.get("quietUntil") as Timestamp | null | undefined)?.toMillis() ?? 0;
    if (quietUntil > now) continue;
    const settings = { ...DEFAULT_CHILD_SETTINGS, ...(child.get("settings") ?? {}) };
    if (!settings.guardMode) continue;
    const lastTs = (live.get("ts") as Timestamp).toMillis();
    const minutes = Math.round((now - lastTs) / 60_000);
    if (minutes < settings.offlineAlertMin) continue;

    const battery = live.get("battery") as number | undefined;
    await raiseAlert(fref.id, {
      type: "offline",
      childId: cid,
      childName: child.get("name"),
      lat: live.get("lat"),
      lng: live.get("lng"),
      title: `${child.get("name")}'s phone stopped sharing`,
      body: `No update for ${minutes} min${battery != null ? ` (battery was ${battery}%)` : ""}. Last known location is on the map.`,
    });
    await state.ref.set({ offlineAlerted: true }, { merge: true });
  }
});

/** Daily: downgrade families whose paid period lapsed (with a 3-day grace period). */
export const expireSubscriptions = onSchedule({ schedule: "every day 03:00", timeZone: "Asia/Colombo" }, async () => {
  const cutoff = Timestamp.fromMillis(Date.now() - 3 * 86_400_000);
  const lapsed = await db.collection("families").where("planRenewsAt", "<", cutoff).get();
  for (const fam of lapsed.docs) {
    if (fam.get("planId") === "free") continue;
    await fam.ref.update({ planId: "free", planStatus: "expired", planRenewsAt: null, limits: FREE_LIMITS });
    await audit(null, "plan.expired", { familyId: fam.id, previous: fam.get("planId") });
    logger.info("plan expired", { fid: fam.id });
  }
});
