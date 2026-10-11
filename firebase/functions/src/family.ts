import { onCall, HttpsError } from "firebase-functions/v2/https";
import { z } from "zod";
import { auth, db, familyRef, FieldValue } from "./lib/firebase";
import { parse, requireParent, requireSignedIn } from "./lib/guards";
import { callable } from "./lib/options";
import { effectiveLimits, FREE_LIMITS, withinLimit } from "./lib/plans";
import { DAYS } from "./lib/schedule";
import { audit } from "./lib/audit";

const phoneSchema = z.string().regex(/^\+?[0-9]{9,15}$/);

/** First-time guardian setup: creates a family on the Free plan and sets custom claims. */
export const createFamily = onCall(callable(), async (req) => {
  const uid = requireSignedIn(req);
  const token = req.auth!.token;
  const provider = token.firebase?.sign_in_provider;
  if (provider === "password" && !token.email_verified) {
    throw new HttpsError("failed-precondition", "Please verify your email address first.");
  }
  if (token.familyId) throw new HttpsError("already-exists", "You already belong to a family.");

  const input = parse(
    z.object({
      familyName: z.string().trim().min(1).max(60),
      displayName: z.string().trim().min(1).max(60),
      phone: phoneSchema.optional(),
    }),
    req.data,
  );

  const fref = familyRef(db.collection("families").doc().id);
  const batch = db.batch();
  batch.set(fref, {
    name: input.familyName,
    ownerUid: uid,
    planId: "free",
    planStatus: "active",
    planRenewsAt: null,
    limits: FREE_LIMITS,
    createdAt: FieldValue.serverTimestamp(),
  });
  batch.set(fref.collection("members").doc(uid), {
    role: "parent",
    name: input.displayName,
    phone: input.phone ?? null,
    smsAlerts: true,
    owner: true,
    joinedAt: FieldValue.serverTimestamp(),
  });
  batch.set(
    db.collection("users").doc(uid),
    {
      role: "parent",
      familyId: fref.id,
      displayName: input.displayName,
      email: token.email ?? null,
      phone: input.phone ?? null,
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await batch.commit();
  await auth.setCustomUserClaims(uid, { role: "parent", familyId: fref.id });
  return { familyId: fref.id };
});

// ---------- places ----------

const placeSchema = z.object({
  id: z.string().regex(/^[A-Za-z0-9]{1,40}$/).optional(),
  name: z.string().trim().min(1).max(40),
  type: z.enum(["home", "school", "class", "relative", "other"]),
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  radius: z.number().int().min(50).max(2000),
  notifyEnter: z.boolean(),
  notifyExit: z.boolean(),
});

export const savePlace = onCall(callable(), async (req) => {
  const c = requireParent(req);
  const p = parse(placeSchema, req.data);
  const fref = familyRef(c.familyId);
  const col = fref.collection("places");
  const ref = p.id ? col.doc(p.id) : col.doc();

  await db.runTransaction(async (tx) => {
    const [fam, existing, count] = await Promise.all([
      tx.get(fref),
      tx.get(ref),
      tx.get(col.count()),
    ]);
    if (!existing.exists && !withinLimit(fam.get("limits"), "maxPlaces", count.data().count)) {
      throw new HttpsError("resource-exhausted", "Your plan's safe-place limit is reached. Upgrade to add more.");
    }
    const { id: _id, ...data } = p;
    tx.set(ref, { ...data, updatedAt: FieldValue.serverTimestamp(), updatedBy: c.uid }, { merge: true });
  });
  return { id: ref.id };
});

export const deletePlace = onCall(callable(), async (req) => {
  const c = requireParent(req);
  const { id } = parse(z.object({ id: z.string().regex(/^[A-Za-z0-9]{1,40}$/) }), req.data);
  const fref = familyRef(c.familyId);
  const schedules = await fref.collection("schedules").where("placeId", "==", id).get();
  const batch = db.batch();
  schedules.docs.forEach((d) => batch.delete(d.ref));
  batch.delete(fref.collection("places").doc(id));
  await batch.commit();
  return { ok: true };
});

// ---------- schedules ----------

const scheduleSchema = z.object({
  id: z.string().regex(/^[A-Za-z0-9]{1,40}$/).optional(),
  childId: z.string().min(1).max(128),
  placeId: z.string().regex(/^[A-Za-z0-9]{1,40}$/),
  label: z.string().trim().min(1).max(40),
  days: z.array(z.enum(DAYS)).min(1).max(7),
  arriveBy: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),
  graceMin: z.number().int().min(0).max(60).default(10),
  tz: z.string().max(64).default("Asia/Colombo"),
  active: z.boolean().default(true),
});

export const saveSchedule = onCall(callable(), async (req) => {
  const c = requireParent(req);
  const s = parse(scheduleSchema, req.data);
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: s.tz });
  } catch {
    throw new HttpsError("invalid-argument", "Unknown time zone.");
  }
  const fref = familyRef(c.familyId);
  const col = fref.collection("schedules");
  const ref = s.id ? col.doc(s.id) : col.doc();

  await db.runTransaction(async (tx) => {
    const [fam, existing, count, child, place] = await Promise.all([
      tx.get(fref),
      tx.get(ref),
      tx.get(col.count()),
      tx.get(fref.collection("children").doc(s.childId)),
      tx.get(fref.collection("places").doc(s.placeId)),
    ]);
    if (!child.exists || !place.exists) throw new HttpsError("not-found", "Child or place not found.");
    if (!existing.exists && !withinLimit(fam.get("limits"), "maxSchedules", count.data().count)) {
      throw new HttpsError("resource-exhausted", "Your plan's schedule limit is reached. Upgrade to add more.");
    }
    const { id: _id, ...data } = s;
    tx.set(ref, { ...data, familyId: c.familyId, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  });
  return { id: ref.id };
});

export const deleteSchedule = onCall(callable(), async (req) => {
  const c = requireParent(req);
  const { id } = parse(z.object({ id: z.string().regex(/^[A-Za-z0-9]{1,40}$/) }), req.data);
  await familyRef(c.familyId).collection("schedules").doc(id).delete();
  return { ok: true };
});

// ---------- account lifecycle ----------

/** PDPA "right to erasure". The owner deletes the whole family; a co-guardian just leaves. */
export const deleteMyAccount = onCall(callable({ timeoutSeconds: 300 }), async (req) => {
  const c = requireParent(req);
  const fref = familyRef(c.familyId);
  const fam = await fref.get();

  if (fam.get("ownerUid") === c.uid) {
    const members = await fref.collection("members").get();
    await db.recursiveDelete(fref);
    for (const m of members.docs) {
      await db.recursiveDelete(db.collection("users").doc(m.id));
      await auth.deleteUser(m.id).catch(() => undefined);
    }
  } else {
    await fref.collection("members").doc(c.uid).delete();
    await db.recursiveDelete(db.collection("users").doc(c.uid));
    await auth.deleteUser(c.uid);
  }
  await audit(c.uid, "account.delete", { familyId: c.familyId });
  return { ok: true };
});

/** Lets the app show remaining quota without granting write access to limits. */
export const getUsage = onCall(callable(), async (req) => {
  const c = requireParent(req);
  const fref = familyRef(c.familyId);
  const [fam, children, places, schedules, guardians] = await Promise.all([
    fref.get(),
    fref.collection("children").count().get(),
    fref.collection("places").count().get(),
    fref.collection("schedules").count().get(),
    fref.collection("members").where("role", "==", "parent").count().get(),
  ]);
  return {
    limits: effectiveLimits(fam.get("limits")),
    usage: {
      children: children.data().count,
      places: places.data().count,
      schedules: schedules.data().count,
      guardians: Math.max(0, guardians.data().count - 1),
    },
  };
});
