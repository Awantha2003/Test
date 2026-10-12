import { createHash } from "node:crypto";
import { HttpsError } from "firebase-functions/v2/https";
import { db, Timestamp } from "./firebase";

/**
 * Fixed-window rate limiter backed by Firestore (works across function instances).
 * Keys are hashed so IPs and uids aren't stored in clear text.
 */
export async function rateLimit(key: string, max: number, windowSec: number): Promise<void> {
  const id = createHash("sha256").update(key).digest("hex").slice(0, 40);
  const ref = db.collection("rateLimits").doc(id);
  const now = Date.now();
  const allowed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const d = snap.data() as { count: number; windowStart: number } | undefined;
    if (!d || now - d.windowStart >= windowSec * 1000) {
      tx.set(ref, { count: 1, windowStart: now, expireAt: Timestamp.fromMillis(now + windowSec * 2000) });
      return true;
    }
    if (d.count >= max) return false;
    tx.update(ref, { count: d.count + 1 });
    return true;
  });
  if (!allowed) throw new HttpsError("resource-exhausted", "Too many requests. Please wait and try again.");
}
