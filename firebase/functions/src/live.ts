import { onCall, HttpsError } from "firebase-functions/v2/https";
import { z } from "zod";
import { familyRef, FieldValue, Timestamp } from "./lib/firebase";
import { parse, requireParent } from "./lib/guards";
import { callable } from "./lib/options";
import { rateLimit } from "./lib/ratelimit";

/** Longest a single live session can run before a guardian must renew it (battery). */
export const MAX_LIVE_MINUTES = 30;

/**
 * Guardian opens "Live track": the child's phone switches to fast updates
 * (every ~5 s instead of ~30 s) until `liveUntil`. The child app shows a banner
 * while this is on, so live viewing is never hidden from the child.
 * minutes = 0 stops it early (guardian closed the screen).
 */
export const setLiveTracking = onCall(callable(), async (req) => {
  const c = requireParent(req);
  const { childId, minutes } = parse(
    z.object({ childId: z.string().min(1).max(128), minutes: z.number().int().min(0).max(MAX_LIVE_MINUTES) }),
    req.data,
  );
  await rateLimit(`live:${c.uid}`, 30, 3600);
  const ref = familyRef(c.familyId).collection("children").doc(childId);
  const child = await ref.get();
  if (!child.exists) throw new HttpsError("not-found", "Child not found.");

  const liveUntil = minutes === 0 ? null : Timestamp.fromMillis(Date.now() + minutes * 60_000);
  await ref.update({ liveUntil, liveBy: minutes === 0 ? null : c.uid, liveUpdatedAt: FieldValue.serverTimestamp() });
  return { liveUntil: liveUntil?.toMillis() ?? null };
});
