import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { defineBoolean, defineSecret, defineString } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import { randomBytes } from "node:crypto";
import { z } from "zod";
import { db, familyRef, FieldValue, Timestamp } from "./lib/firebase";
import { parse, requireParent } from "./lib/guards";
import { callable } from "./lib/options";
import { rateLimit } from "./lib/ratelimit";
import { addPeriod, DEFAULT_PLANS, FREE_LIMITS, Plan } from "./lib/plans";
import { checkoutHash, checkoutUrl, formatAmount, PAYHERE_STATUS, PayHereNotify, verifyNotify } from "./lib/payhere";
import { audit } from "./lib/audit";

export const PAYHERE_MERCHANT_ID = defineString("PAYHERE_MERCHANT_ID");
/** PayHere issues one merchant secret per whitelisted domain and per mobile app package. */
export const PAYHERE_MERCHANT_SECRET = defineSecret("PAYHERE_MERCHANT_SECRET");
export const PAYHERE_APP_MERCHANT_SECRET = defineSecret("PAYHERE_APP_MERCHANT_SECRET");
export const PAYHERE_SANDBOX = defineBoolean("PAYHERE_SANDBOX", { default: true });
export const PUBLIC_WEB_URL = defineString("PUBLIC_WEB_URL", { default: "https://rakawala.lk" });
export const PAYHERE_NOTIFY_URL = defineString("PAYHERE_NOTIFY_URL");

export async function loadPlan(planId: string): Promise<Plan | null> {
  const snap = await db.collection("plans").doc(planId).get();
  if (snap.exists) return { id: snap.id, ...(snap.data() as Omit<Plan, "id">) };
  return DEFAULT_PLANS.find((p) => p.id === planId) ?? null;
}

/** Builds signed PayHere checkout params. The merchant secret never leaves the server. */
export const createCheckout = onCall(callable({ secrets: [PAYHERE_MERCHANT_SECRET] }), async (req) => {
  const c = requireParent(req);
  const { planId, channel } = parse(
    z.object({ planId: z.string().regex(/^[a-z0-9_]{1,40}$/), channel: z.enum(["web", "app"]).default("web") }),
    req.data,
  );
  await rateLimit(`checkout:${c.uid}`, 10, 3600);

  const plan = await loadPlan(planId);
  if (!plan || !plan.active || plan.interval === "free" || plan.priceLkr <= 0) {
    throw new HttpsError("invalid-argument", "That plan isn't available.");
  }
  const [user, fam] = await Promise.all([db.collection("users").doc(c.uid).get(), familyRef(c.familyId).get()]);
  if (fam.get("ownerUid") !== c.uid) throw new HttpsError("permission-denied", "Only the family owner can change the plan.");
  const orderId = `RK${Date.now().toString(36).toUpperCase()}${randomBytes(4).toString("hex").toUpperCase()}`;
  const amount = formatAmount(plan.priceLkr);
  const currency = "LKR";
  const merchantId = PAYHERE_MERCHANT_ID.value();

  await db.collection("payments").doc(orderId).set({
    familyId: c.familyId,
    planId: plan.id,
    amount,
    currency,
    status: "initiated",
    createdBy: c.uid,
    createdAt: FieldValue.serverTimestamp(),
    paymentIds: [],
  });

  const [firstName, ...rest] = String(user.get("displayName") ?? "Rakawala Parent").split(" ");
  const web = PUBLIC_WEB_URL.value();
  return {
    sandbox: PAYHERE_SANDBOX.value(),
    checkoutUrl: checkoutUrl(PAYHERE_SANDBOX.value()),
    params: {
      merchant_id: merchantId,
      return_url: `${web}/dashboard/billing?status=success&order=${orderId}`,
      cancel_url: `${web}/dashboard/billing?status=cancelled`,
      notify_url: PAYHERE_NOTIFY_URL.value(),
      order_id: orderId,
      items: `Rakawala ${plan.name}`,
      currency,
      amount,
      recurrence: plan.interval === "year" ? "1 Year" : "1 Month",
      duration: "Forever",
      first_name: firstName || "Parent",
      last_name: rest.join(" ") || "-",
      email: (user.get("email") as string) ?? "",
      phone: (user.get("phone") as string) ?? "",
      address: "-",
      city: "Colombo",
      country: "Sri Lanka",
      custom_1: c.familyId,
      custom_2: plan.id,
      // The web checkout form needs a hash. The mobile SDK authenticates via the app's package name instead.
      ...(channel === "web"
        ? { hash: checkoutHash(merchantId, orderId, plan.priceLkr, currency, PAYHERE_MERCHANT_SECRET.value()) }
        : {}),
    },
    familyName: fam.get("name") ?? "",
  };
});

/**
 * PayHere server-to-server notification (initial payment and every recurring charge).
 * Trust nothing in the body until md5sig verifies; then cross-check amount/currency
 * against our own order record. Idempotent per payment_id.
 */
export const payhereNotify = onRequest(
  { secrets: [PAYHERE_MERCHANT_SECRET, PAYHERE_APP_MERCHANT_SECRET], cors: false, maxInstances: 10 },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }
    const n = req.body as PayHereNotify;
    const merchantId = PAYHERE_MERCHANT_ID.value();
    const secrets = [PAYHERE_MERCHANT_SECRET.value(), PAYHERE_APP_MERCHANT_SECRET.value()].filter(Boolean);
    if (!secrets.some((secret) => verifyNotify(n, merchantId, secret))) {
      logger.warn("payhere signature mismatch", { order: String(n?.order_id ?? "").slice(0, 40) });
      res.status(400).send("Invalid signature");
      return;
    }

    const payRef = db.collection("payments").doc(String(n.order_id));
    const outcome = await db.runTransaction(async (tx) => {
      const pay = await tx.get(payRef);
      if (!pay.exists) return "unknown-order";
      if (pay.get("amount") !== n.payhere_amount || pay.get("currency") !== n.payhere_currency) {
        tx.update(payRef, { status: "amount-mismatch", lastNotifyAt: FieldValue.serverTimestamp() });
        return "amount-mismatch";
      }
      const paymentId = String(n.payment_id ?? n.subscription_id ?? n.status_code);
      const eventKey = `${paymentId}:${n.status_code}:${n.message_type ?? ""}`;
      if ((pay.get("processed") as string[] | undefined)?.includes(eventKey)) return "duplicate";

      const fref = familyRef(pay.get("familyId"));
      const fam = await tx.get(fref);
      const plan = DEFAULT_PLANS.find((p) => p.id === pay.get("planId"));
      const planDoc = await tx.get(db.collection("plans").doc(pay.get("planId")));
      const effectivePlan: Plan | undefined = planDoc.exists ? ({ id: planDoc.id, ...planDoc.data() } as Plan) : plan;

      const common = {
        processed: FieldValue.arrayUnion(eventKey),
        lastNotifyAt: FieldValue.serverTimestamp(),
        subscriptionId: n.subscription_id ?? pay.get("subscriptionId") ?? null,
        method: n.method ?? null,
      };

      if (n.status_code === PAYHERE_STATUS.SUCCESS && effectivePlan && n.item_rec_status !== "-1") {
        const currentRenew = (fam.get("planRenewsAt") as Timestamp | null)?.toDate();
        const base = currentRenew && currentRenew > new Date() && fam.get("planId") === effectivePlan.id ? currentRenew : new Date();
        const renews = addPeriod(base, effectivePlan.interval);
        tx.update(fref, {
          planId: effectivePlan.id,
          planStatus: "active",
          planRenewsAt: Timestamp.fromDate(renews),
          limits: effectivePlan.limits,
          subscriptionId: n.subscription_id ?? null,
        });
        tx.update(payRef, { ...common, status: "paid", paymentIds: FieldValue.arrayUnion(paymentId) });
        return "paid";
      }
      if (n.status_code === PAYHERE_STATUS.CHARGEDBACK) {
        tx.update(fref, { planId: "free", planStatus: "chargeback", planRenewsAt: null, limits: FREE_LIMITS });
        tx.update(payRef, { ...common, status: "chargeback" });
        return "chargeback";
      }
      if (n.item_rec_status === "-1" || n.message_type === "RECURRING_STOPPED") {
        // Keep access until the paid period ends; the daily job downgrades afterwards.
        tx.update(fref, { planStatus: "cancelled" });
        tx.update(payRef, { ...common, status: "subscription-stopped" });
        return "stopped";
      }
      const status = { [PAYHERE_STATUS.PENDING]: "pending", [PAYHERE_STATUS.CANCELLED]: "cancelled", [PAYHERE_STATUS.FAILED]: "failed" }[n.status_code] ?? `status-${n.status_code}`;
      tx.update(payRef, { ...common, status });
      return status;
    });

    logger.info("payhere notify", { order: n.order_id, outcome });
    if (outcome === "paid" || outcome === "chargeback") await audit(null, `billing.${outcome}`, { orderId: n.order_id });
    // 200 for anything with a valid signature so PayHere doesn't retry forever; problems are logged.
    res.status(200).send("OK");
  },
);
