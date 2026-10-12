import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { randomBytes } from "node:crypto";
import { z } from "zod";
import { auth, db, familyRef, FieldValue, Timestamp } from "./lib/firebase";
import { clientIp, parse, requireParent, requireSignedIn } from "./lib/guards";
import { callable } from "./lib/options";
import { rateLimit } from "./lib/ratelimit";
import { withinLimit } from "./lib/plans";
import { CODE_TTL_MS, formatCode, generateCode, hashCode, normalizeCode } from "./lib/codes";
import { raiseAlert } from "./lib/notify";
import { audit } from "./lib/audit";

const CHILD_COLORS = ["#2563EB", "#DB2777", "#059669", "#D97706", "#7C3AED", "#DC2626"];

export const DEFAULT_CHILD_SETTINGS = {
  speedLimitKmh: 70,
  lowBatteryPct: 15,
  guardMode: true,
  voiceSos: false,
  safeWord: "",
  offlineAlertMin: 45,
};

/** Guardian creates a one-time code to pair a child phone or invite a co-guardian. */
export const createPairingCode = onCall(callable(), async (req) => {
  const c = requireParent(req);
  const input = parse(
    z.discriminatedUnion("kind", [
      z.object({ kind: z.literal("child"), childName: z.string().trim().min(1).max(40), childId: z.string().max(128).optional() }),
      z.object({ kind: z.literal("guardian") }),
    ]),
    req.data,
  );
  await rateLimit(`pair-create:${c.uid}`, 10, 3600);

  const fref = familyRef(c.familyId);
  const fam = await fref.get();
  if (input.kind === "child") {
    if (input.childId) {
      const child = await fref.collection("children").doc(input.childId).get();
      if (!child.exists) throw new HttpsError("not-found", "Child not found.");
    } else {
      const n = (await fref.collection("children").count().get()).data().count;
      if (!withinLimit(fam.get("limits"), "maxChildren", n)) {
        throw new HttpsError("resource-exhausted", "Your plan's child limit is reached. Upgrade to add more.");
      }
    }
  } else {
    const n = (await fref.collection("members").where("role", "==", "parent").count().get()).data().count;
    if (!withinLimit(fam.get("limits"), "maxGuardians", n - 1)) {
      throw new HttpsError("resource-exhausted", "Your plan's co-guardian limit is reached. Upgrade to add more.");
    }
  }

  // Retry on the (astronomically unlikely) collision with a live code.
  for (let i = 0; i < 3; i++) {
    const code = generateCode();
    const ref = db.collection("pairingCodes").doc(hashCode(code));
    const expiresAt = Timestamp.fromMillis(Date.now() + CODE_TTL_MS);
    try {
      await ref.create({
        familyId: c.familyId,
        kind: input.kind,
        childName: input.kind === "child" ? input.childName : null,
        childId: input.kind === "child" ? (input.childId ?? null) : null,
        createdBy: c.uid,
        createdAt: FieldValue.serverTimestamp(),
        expiresAt,
        expireAt: Timestamp.fromMillis(Date.now() + 24 * 3600 * 1000), // TTL cleanup
        used: false,
      });
      return { code: formatCode(code), expiresAt: expiresAt.toMillis() };
    } catch (e) {
      if ((e as { code?: number }).code !== 6 /* ALREADY_EXISTS */) throw e;
    }
  }
  throw new HttpsError("internal", "Could not create a code. Try again.");
});

const redeemSchema = z.object({
  code: z.string().min(8).max(12),
  deviceName: z.string().trim().max(60).default("Phone"),
  platform: z.enum(["android", "ios"]),
});

/**
 * Child phone redeems a code and receives a custom auth token.
 * Unauthenticated by design (fresh device), so it's protected by App Check,
 * a per-IP rate limit, a 10-minute TTL, single use, and a 31^8 code space.
 */
export const redeemPairingCode = onCall(callable(), async (req) => {
  await rateLimit(`pair-redeem:${clientIp(req)}`, 10, 600);
  const input = parse(redeemSchema, req.data);
  const code = normalizeCode(input.code);
  if (!code) throw new HttpsError("invalid-argument", "That code doesn't look right.");
  const codeRef = db.collection("pairingCodes").doc(hashCode(code));

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(codeRef);
    if (!snap.exists || snap.get("used") === true || snap.get("kind") !== "child") return null;
    if ((snap.get("expiresAt") as Timestamp).toMillis() < Date.now()) return null;

    const fid = snap.get("familyId") as string;
    const fref = familyRef(fid);
    let childId = snap.get("childId") as string | null;
    let childName = snap.get("childName") as string;
    const pairing = {
      paired: true,
      pairedAt: FieldValue.serverTimestamp(),
      deviceName: input.deviceName,
      platform: input.platform,
    };
    if (childId) {
      const existing = await tx.get(fref.collection("children").doc(childId));
      if (!existing.exists) return null;
      childName = existing.get("name");
      tx.update(existing.ref, pairing);
    } else {
      const [fam, count] = await Promise.all([tx.get(fref), tx.get(fref.collection("children").count())]);
      if (!withinLimit(fam.get("limits"), "maxChildren", count.data().count)) {
        throw new HttpsError("resource-exhausted", "This family's plan is full.");
      }
      childId = `c_${randomBytes(12).toString("hex")}`;
      tx.set(fref.collection("children").doc(childId), {
        name: childName,
        color: CHILD_COLORS[count.data().count % CHILD_COLORS.length],
        settings: DEFAULT_CHILD_SETTINGS,
        createdAt: FieldValue.serverTimestamp(),
        ...pairing,
      });
      tx.set(fref.collection("members").doc(childId), {
        role: "child",
        name: childName,
        joinedAt: FieldValue.serverTimestamp(),
      });
      tx.set(db.collection("users").doc(childId), {
        role: "child",
        familyId: fid,
        displayName: childName,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    tx.update(codeRef, { used: true, usedAt: FieldValue.serverTimestamp() });
    return { fid, childId, childName, createdBy: snap.get("createdBy") as string };
  });

  if (!result) {
    logger.warn("pairing redeem failed", { ipHash: hashCode(clientIp(req)).slice(0, 12) });
    throw new HttpsError("not-found", "Code is invalid or expired. Ask your parent for a new one.");
  }

  const { fid, childId, childName } = result;
  const claims = { role: "child", familyId: fid };
  try {
    await auth.getUser(childId);
    await auth.revokeRefreshTokens(childId); // re-pair: the old phone loses access
  } catch {
    await auth.createUser({ uid: childId, displayName: childName });
  }
  await auth.setCustomUserClaims(childId, claims);
  const token = await auth.createCustomToken(childId, claims);

  // Every guardian learns that a device was paired, so a rogue pairing can't go unnoticed.
  await raiseAlert(fid, {
    type: "checkin",
    childId,
    childName,
    title: `${childName}'s phone is connected`,
    body: `${input.deviceName} (${input.platform}) is now sharing location with your family.`,
  });
  await audit(result.createdBy, "child.paired", { familyId: fid, childId });
  return { token, childId, childName, familyId: fid };
});

/** A signed-in guardian without a family joins one with an invite code. */
export const redeemGuardianInvite = onCall(callable(), async (req) => {
  const uid = requireSignedIn(req);
  const token = req.auth!.token;
  if (token.familyId) throw new HttpsError("already-exists", "You already belong to a family.");
  if (token.firebase?.sign_in_provider === "password" && !token.email_verified) {
    throw new HttpsError("failed-precondition", "Please verify your email address first.");
  }
  await rateLimit(`invite-redeem:${uid}`, 10, 600);
  const input = parse(
    z.object({ code: z.string().min(8).max(12), displayName: z.string().trim().min(1).max(60), phone: z.string().regex(/^\+?[0-9]{9,15}$/).optional() }),
    req.data,
  );
  const code = normalizeCode(input.code);
  if (!code) throw new HttpsError("invalid-argument", "That code doesn't look right.");
  const codeRef = db.collection("pairingCodes").doc(hashCode(code));

  const fid = await db.runTransaction(async (tx) => {
    const snap = await tx.get(codeRef);
    if (!snap.exists || snap.get("used") === true || snap.get("kind") !== "guardian") return null;
    if ((snap.get("expiresAt") as Timestamp).toMillis() < Date.now()) return null;
    const familyId = snap.get("familyId") as string;
    const fref = familyRef(familyId);
    const [fam, count] = await Promise.all([
      tx.get(fref),
      tx.get(fref.collection("members").where("role", "==", "parent").count()),
    ]);
    if (!withinLimit(fam.get("limits"), "maxGuardians", count.data().count - 1)) {
      throw new HttpsError("resource-exhausted", "This family's plan has no free guardian seats.");
    }
    tx.set(fref.collection("members").doc(uid), {
      role: "parent",
      name: input.displayName,
      phone: input.phone ?? null,
      smsAlerts: true,
      owner: false,
      joinedAt: FieldValue.serverTimestamp(),
    });
    tx.set(
      db.collection("users").doc(uid),
      { role: "parent", familyId, displayName: input.displayName, email: token.email ?? null, phone: input.phone ?? null, createdAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    tx.update(codeRef, { used: true, usedAt: FieldValue.serverTimestamp(), usedBy: uid });
    return familyId;
  });
  if (!fid) throw new HttpsError("not-found", "Invite code is invalid or expired.");
  await auth.setCustomUserClaims(uid, { role: "parent", familyId: fid });
  await audit(uid, "guardian.joined", { familyId: fid });
  return { familyId: fid };
});

/** Unpair a child: delete their device identity and all location data. */
export const removeChild = onCall(callable({ timeoutSeconds: 120 }), async (req) => {
  const c = requireParent(req);
  const { childId } = parse(z.object({ childId: z.string().min(1).max(128) }), req.data);
  const fref = familyRef(c.familyId);
  const child = await fref.collection("children").doc(childId).get();
  if (!child.exists) throw new HttpsError("not-found", "Child not found.");

  await auth.deleteUser(childId).catch(() => undefined);
  const history = await fref.collection("history").where("childId", "==", childId).get();
  const schedules = await fref.collection("schedules").where("childId", "==", childId).get();
  const refs = [
    ...history.docs.map((d) => d.ref),
    ...schedules.docs.map((d) => d.ref),
    fref.collection("live").doc(childId),
    fref.collection("geostate").doc(childId),
    fref.collection("members").doc(childId),
    fref.collection("children").doc(childId),
    db.collection("users").doc(childId),
  ];
  const writer = db.bulkWriter();
  refs.forEach((r) => writer.delete(r));
  await writer.close();
  await audit(c.uid, "child.removed", { familyId: c.familyId, childId });
  return { ok: true };
});

/** Owner removes a co-guardian. */
export const removeGuardian = onCall(callable(), async (req) => {
  const c = requireParent(req);
  const { uid } = parse(z.object({ uid: z.string().min(1).max(128) }), req.data);
  const fref = familyRef(c.familyId);
  const fam = await fref.get();
  if (fam.get("ownerUid") !== c.uid) throw new HttpsError("permission-denied", "Only the family owner can remove guardians.");
  if (uid === c.uid) throw new HttpsError("invalid-argument", "Use account deletion to leave as the owner.");
  const member = await fref.collection("members").doc(uid).get();
  if (!member.exists || member.get("role") !== "parent") throw new HttpsError("not-found", "Guardian not found.");

  await fref.collection("members").doc(uid).delete();
  await db.collection("users").doc(uid).set({ familyId: null, role: null }, { merge: true });
  await auth.setCustomUserClaims(uid, {});
  await auth.revokeRefreshTokens(uid);
  await audit(c.uid, "guardian.removed", { familyId: c.familyId, uid });
  return { ok: true };
});
