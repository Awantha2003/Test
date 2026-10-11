import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentWrittenWithAuthContext } from "firebase-functions/v2/firestore";
import { z } from "zod";
import { auth, db, familyRef, Timestamp } from "./lib/firebase";
import { parse, requireAdmin } from "./lib/guards";
import { callable } from "./lib/options";
import { addPeriod, DEFAULT_PLANS, FREE_LIMITS } from "./lib/plans";
import { audit } from "./lib/audit";
import { loadPlan } from "./billing";

/** Dashboard numbers. Counts only: admins never see children's locations. */
export const adminStats = onCall(callable(), async (req) => {
  requireAdmin(req);
  const dayAgo = Timestamp.fromMillis(Date.now() - 86_400_000);
  const [families, paying, children, sos24h, openSos] = await Promise.all([
    db.collection("families").count().get(),
    db.collection("families").where("planId", "!=", "free").count().get(),
    db.collectionGroup("children").count().get(),
    db.collectionGroup("alerts").where("type", "==", "sos").where("createdAt", ">=", dayAgo).count().get(),
    db.collectionGroup("alerts").where("type", "==", "sos").where("status", "==", "open").count().get(),
  ]);
  return {
    families: families.data().count,
    payingFamilies: paying.data().count,
    children: children.data().count,
    sosLast24h: sos24h.data().count,
    openSos: openSos.data().count,
  };
});

export const adminSetUserDisabled = onCall(callable(), async (req) => {
  const adminUid = requireAdmin(req);
  const { uid, disabled } = parse(z.object({ uid: z.string().min(1).max(128), disabled: z.boolean() }), req.data);
  if (uid === adminUid) throw new HttpsError("invalid-argument", "You can't disable yourself.");
  await auth.updateUser(uid, { disabled });
  if (disabled) await auth.revokeRefreshTokens(uid);
  await db.collection("users").doc(uid).set({ disabled }, { merge: true });
  await audit(adminUid, disabled ? "admin.user.disable" : "admin.user.enable", { uid });
  return { ok: true };
});

/** Comp / correct a family's plan (support cases, refunds, school partnerships). */
export const adminSetFamilyPlan = onCall(callable(), async (req) => {
  const adminUid = requireAdmin(req);
  const { familyId, planId, periods } = parse(
    z.object({ familyId: z.string().min(1).max(128), planId: z.string().regex(/^[a-z0-9_]{1,40}$/), periods: z.number().int().min(1).max(36).default(1) }),
    req.data,
  );
  const fref = familyRef(familyId);
  if (!(await fref.get()).exists) throw new HttpsError("not-found", "Family not found.");
  if (planId === "free") {
    await fref.update({ planId: "free", planStatus: "active", planRenewsAt: null, limits: FREE_LIMITS });
  } else {
    const plan = await loadPlan(planId);
    if (!plan) throw new HttpsError("not-found", "Plan not found.");
    await fref.update({
      planId: plan.id,
      planStatus: "comped",
      planRenewsAt: Timestamp.fromDate(addPeriod(new Date(), plan.interval, periods)),
      limits: plan.limits,
    });
  }
  await audit(adminUid, "admin.family.setPlan", { familyId, planId, periods });
  return { ok: true };
});

/** Seed default plans and site content (only creates what is missing). */
export const adminSeed = onCall(callable(), async (req) => {
  const adminUid = requireAdmin(req);
  const batch = db.batch();
  let created = 0;
  for (const p of DEFAULT_PLANS) {
    const ref = db.collection("plans").doc(p.id);
    if (!(await ref.get()).exists) {
      const { id: _id, ...data } = p;
      batch.set(ref, data);
      created++;
    }
  }
  const home = db.collection("siteContent").doc("home");
  if (!(await home.get()).exists) {
    batch.set(home, {
      heroTitle: "Know they're safe. Every step of the way.",
      heroSubtitle: "Live location, class-arrival alerts and one-tap SOS for Sri Lankan families.",
      announcement: "",
      faq: [
        { q: "Does my child know they're being shared?", a: "Yes. Rakawala is built for families, not spying. The child's phone always shows that sharing is on." },
        { q: "Does SOS work without mobile data?", a: "Yes. If there's no internet, the child's phone sends an SMS with a map link to guardians." },
        { q: "How do I pay?", a: "Visa, Mastercard, Amex, eZ Cash, mCash and Genie via PayHere. Cancel anytime." },
      ],
    });
    created++;
  }
  await batch.commit();
  await audit(adminUid, "admin.seed", { created });
  return { created };
});

/** Audit every admin edit to the public catalogue and website content. */
export const auditPlans = onDocumentWrittenWithAuthContext("plans/{planId}", async (event) => {
  await audit(event.authId ?? null, "plans.write", {
    planId: event.params.planId,
    deleted: !event.data?.after.exists,
  });
});

export const auditSiteContent = onDocumentWrittenWithAuthContext("siteContent/{docId}", async (event) => {
  await audit(event.authId ?? null, "siteContent.write", { docId: event.params.docId });
});
