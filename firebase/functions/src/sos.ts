import { onCall, HttpsError } from "firebase-functions/v2/https";
import { z } from "zod";
import { familyRef, FieldValue } from "./lib/firebase";
import { parse, requireChild, requireParent } from "./lib/guards";
import { callable } from "./lib/options";
import { rateLimit } from "./lib/ratelimit";
import { mapsLink } from "./lib/geo";
import { effectiveLimits } from "./lib/plans";
import { raiseAlert, smsGuardians, NOTIFYLK_API_KEY } from "./lib/notify";

const positionSchema = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  accuracy: z.number().min(0).max(100000).optional(),
});

/**
 * SOS from the child device (button hold, voice safe-word or notification action).
 * Push goes to every guardian on every plan. SMS also goes out on paid plans.
 */
export const triggerSos = onCall(callable({ secrets: [NOTIFYLK_API_KEY], minInstances: 0 }), async (req) => {
  const c = requireChild(req);
  const input = parse(
    z.object({
      position: positionSchema.nullable(),
      source: z.enum(["button", "voice", "notification", "shake"]),
      battery: z.number().min(0).max(100).optional(),
    }),
    req.data,
  );
  // Generous limit: a frightened child pressing repeatedly must still get through,
  // but a script can't flood guardians.
  await rateLimit(`sos:${c.uid}`, 6, 300);

  const fref = familyRef(c.familyId);
  const [fam, child] = await Promise.all([fref.get(), fref.collection("children").doc(c.uid).get()]);
  if (!child.exists) throw new HttpsError("not-found", "This phone is no longer paired.");
  const childName = (child.get("name") as string) ?? "Your child";
  const pos = input.position;
  const where = pos ? mapsLink(pos) : "location unavailable";
  const via = { button: "SOS button", voice: "voice safe-word", notification: "SOS shortcut", shake: "shake" }[input.source];

  const alertId = await raiseAlert(c.familyId, {
    type: "sos",
    childId: c.uid,
    childName,
    ...(pos ? { lat: pos.lat, lng: pos.lng } : {}),
    title: `🚨 SOS from ${childName}`,
    body: `${childName} needs help (${via}). Tap to see their location.`,
  });
  await fref.collection("alerts").doc(alertId).update({
    source: input.source,
    battery: input.battery ?? null,
    accuracy: pos?.accuracy ?? null,
  });

  let sms = 0;
  if (effectiveLimits(fam.get("limits")).smsSos) {
    sms = await smsGuardians(c.familyId, `RAKAWALA SOS: ${childName} needs help. Location: ${where}`);
  }
  return { alertId, sms };
});

/** "I'm safe" check-in from the child. */
export const checkIn = onCall(callable(), async (req) => {
  const c = requireChild(req);
  const input = parse(z.object({ position: positionSchema.nullable(), message: z.string().trim().max(80).optional() }), req.data);
  await rateLimit(`checkin:${c.uid}`, 10, 600);
  const child = await familyRef(c.familyId).collection("children").doc(c.uid).get();
  const childName = (child.get("name") as string) ?? "Your child";
  const alertId = await raiseAlert(c.familyId, {
    type: "checkin",
    childId: c.uid,
    childName,
    ...(input.position ? { lat: input.position.lat, lng: input.position.lng } : {}),
    title: `${childName} checked in ✅`,
    body: input.message || "I'm safe.",
  });
  return { alertId };
});

/** Guardian acknowledges / resolves an SOS. */
export const resolveAlert = onCall(callable(), async (req) => {
  const c = requireParent(req);
  const input = parse(
    z.object({ alertId: z.string().regex(/^[A-Za-z0-9]{1,40}$/), status: z.enum(["acknowledged", "resolved"]), note: z.string().max(200).optional() }),
    req.data,
  );
  const ref = familyRef(c.familyId).collection("alerts").doc(input.alertId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "Alert not found.");
  await ref.update({
    status: input.status,
    [`${input.status}By`]: c.uid,
    [`${input.status}At`]: FieldValue.serverTimestamp(),
    note: input.note ?? null,
  });
  return { ok: true };
});
