import { CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { defineBoolean } from "firebase-functions/params";
import { z } from "zod";

export const REQUIRE_ADMIN_MFA = defineBoolean("REQUIRE_ADMIN_MFA", { default: true });

export interface Caller {
  uid: string;
  familyId: string;
  role: "parent" | "child";
  childId?: string;
}

function claimsOf(req: CallableRequest) {
  if (!req.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  return req.auth.token as Record<string, unknown>;
}

export function requireSignedIn(req: CallableRequest): string {
  claimsOf(req);
  return req.auth!.uid;
}

export function requireParent(req: CallableRequest): Caller {
  const c = claimsOf(req);
  if (c.role !== "parent" || typeof c.familyId !== "string") {
    throw new HttpsError("permission-denied", "Guardian account required.");
  }
  return { uid: req.auth!.uid, familyId: c.familyId, role: "parent" };
}

export function requireChild(req: CallableRequest): Caller {
  const c = claimsOf(req);
  if (c.role !== "child" || typeof c.familyId !== "string") {
    throw new HttpsError("permission-denied", "Child device required.");
  }
  return { uid: req.auth!.uid, familyId: c.familyId, role: "child", childId: req.auth!.uid };
}

export function requireMember(req: CallableRequest): Caller {
  const c = claimsOf(req);
  return c.role === "child" ? requireChild(req) : requireParent(req);
}

/** Admins must hold the admin claim and (in production) have signed in with a second factor. */
export function requireAdmin(req: CallableRequest): string {
  const c = claimsOf(req);
  if (c.admin !== true) throw new HttpsError("permission-denied", "Admin only.");
  const firebase = (c.firebase ?? {}) as Record<string, unknown>;
  if (REQUIRE_ADMIN_MFA.value() && !firebase.sign_in_second_factor) {
    throw new HttpsError("permission-denied", "Admin actions require multi-factor sign-in.");
  }
  return req.auth!.uid;
}

/** Validate a callable payload; error messages never echo raw input back. */
export function parse<T extends z.ZodTypeAny>(schema: T, data: unknown): z.infer<T> {
  const r = schema.safeParse(data);
  if (!r.success) {
    const fields = r.error.issues.map((i) => i.path.join(".") || "(root)").join(", ");
    throw new HttpsError("invalid-argument", `Invalid request: ${fields}`);
  }
  return r.data;
}

/**
 * Caller IP as resolved by the platform. We deliberately don't read the left-most
 * X-Forwarded-For entry because the client controls it. IP limits are only a
 * secondary control; App Check and per-code attempt counters are the primary ones.
 */
export function clientIp(req: { rawRequest?: { ip?: string } }): string {
  return req.rawRequest?.ip || "unknown";
}
