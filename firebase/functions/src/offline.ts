import { onCall, HttpsError } from "firebase-functions/v2/https";
import { z } from "zod";
import { db, familyRef, FieldValue, Timestamp } from "./lib/firebase";
import { parse, requireMember } from "./lib/guards";
import { callable } from "./lib/options";
import { rateLimit } from "./lib/ratelimit";
import { evaluateGeofences, Place } from "./lib/geo";
import { effectiveLimits } from "./lib/plans";
import { clampQuietMinutes, MAX_TRAIL_POINTS, sanitizeTrail } from "./lib/trail";
import { raiseAlert } from "./lib/notify";

const pointSchema = z.object({
  lat: z.number(),
  lng: z.number(),
  accuracy: z.number(),
  speed: z.number().optional(),
  battery: z.number().int().min(0).max(100).optional(),
  ts: z.number().int(),
});

/**
 * A child phone uploads the locations it recorded while it had no data connection,
 * so guardians see the full route instead of a gap. Points become normal history
 * (same TTL as the plan), and safe places entered offline count for schedules, so
 * a child who reached class without signal doesn't trigger a false "late" alert.
 */
export const uploadOfflineTrail = onCall(callable(), async (req) => {
  const c = requireMember(req);
  if (c.role !== "child") throw new HttpsError("permission-denied", "Child device required.");
  const { points } = parse(z.object({ points: z.array(pointSchema).min(1).max(MAX_TRAIL_POINTS * 2) }), req.data);
  await rateLimit(`trail:${c.uid}`, 30, 3600);

  const now = Date.now();
  const clean = sanitizeTrail(points, now);
  if (clean.length === 0) return { stored: 0 };

  const fref = familyRef(c.familyId);
  const [fam, placesSnap, stateSnap] = await Promise.all([
    fref.get(),
    fref.collection("places").get(),
    fref.collection("geostate").doc(c.uid).get(),
  ]);
  const limits = effectiveLimits(fam.get("limits"));

  const writer = db.bulkWriter();
  for (const p of clean) {
    writer.create(fref.collection("history").doc(), {
      childId: c.uid,
      lat: p.lat,
      lng: p.lng,
      accuracy: p.accuracy,
      speed: p.speed ?? null,
      battery: p.battery ?? null,
      ts: Timestamp.fromMillis(p.ts),
      source: "offline",
      expireAt: Timestamp.fromMillis(p.ts + limits.historyDays * 86_400_000),
    });
  }
  await writer.close();

  // Replay the trail through the geofence engine to record arrivals made offline.
  const places: Place[] = placesSnap.docs.map((d) => ({ id: d.id, ...(d.data() as Omit<Place, "id">) }));
  let inside: string[] = (stateSnap.get("inside") as string[] | undefined) ?? [];
  const enteredToday: Record<string, string> = { ...(stateSnap.get("enteredToday") ?? {}) };
  for (const p of clean) {
    const r = evaluateGeofences(inside, places, p);
    inside = r.inside;
    for (const e of r.entered) enteredToday[e.id] = new Date(p.ts).toISOString();
  }
  await stateSnap.ref.set({ enteredToday, offlineAlerted: false }, { merge: true });

  return { stored: clean.length };
});

/**
 * "No signal expected for a while" (train, rural trip, exam hall). Silences the
 * offline alert until the window ends and tells every guardian why.
 * A child sets it for itself; a guardian sets it for any child in the family.
 */
export const setOfflineWindow = onCall(callable(), async (req) => {
  const c = requireMember(req);
  const input = parse(
    z.object({
      childId: z.string().min(1).max(128).optional(),
      minutes: z.number().int().min(0).max(12 * 60),
      reason: z.string().trim().max(60).optional(),
    }),
    req.data,
  );
  const childId = c.role === "child" ? c.uid : input.childId;
  if (!childId) throw new HttpsError("invalid-argument", "Choose a child.");
  await rateLimit(`quiet:${c.uid}`, 20, 3600);

  const fref = familyRef(c.familyId);
  const child = await fref.collection("children").doc(childId).get();
  if (!child.exists) throw new HttpsError("not-found", "Child not found.");
  const stateRef = fref.collection("geostate").doc(childId);

  if (input.minutes === 0) {
    await stateRef.set({ quietUntil: null, quietReason: null }, { merge: true });
    return { quietUntil: null };
  }
  const minutes = clampQuietMinutes(input.minutes);
  const until = Date.now() + minutes * 60_000;
  await stateRef.set(
    { quietUntil: Timestamp.fromMillis(until), quietReason: input.reason ?? null, quietSetBy: c.uid, quietSetAt: FieldValue.serverTimestamp() },
    { merge: true },
  );

  const name = child.get("name") as string;
  const hours = minutes >= 60 ? `${Math.round((minutes / 60) * 10) / 10} h` : `${minutes} min`;
  await raiseAlert(c.familyId, {
    type: "checkin",
    childId,
    childName: name,
    title: `${name} may have no signal for ${hours}`,
    body: `${input.reason ? `${input.reason}. ` : ""}Offline alerts are paused until then. The route will sync when the phone reconnects.`,
  });
  return { quietUntil: until };
});
