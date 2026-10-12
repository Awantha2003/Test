/** Offline trail sanitising. Pure, no Firebase imports. */

export interface TrailPoint {
  lat: number;
  lng: number;
  accuracy: number;
  speed?: number;
  battery?: number;
  ts: number; // epoch ms, recorded on the device
}

export const MAX_TRAIL_POINTS = 500;
/** Points older than this are dropped (phone was off for days, or a bogus clock). */
export const MAX_TRAIL_AGE_MS = 72 * 3600 * 1000;
/** Device clocks drift; allow a little future skew. */
export const MAX_FUTURE_SKEW_MS = 5 * 60 * 1000;
/** Store at most one point per 30 s, to keep history compact. */
export const MIN_POINT_GAP_MS = 30 * 1000;

const valid = (p: TrailPoint) =>
  Number.isFinite(p.lat) && Math.abs(p.lat) <= 90 &&
  Number.isFinite(p.lng) && Math.abs(p.lng) <= 180 &&
  Number.isFinite(p.accuracy) && p.accuracy >= 0 && p.accuracy <= 5000 &&
  Number.isFinite(p.ts);

/**
 * Validate, sort, de-duplicate and thin a batch of points a phone recorded while offline.
 * Never trusts the device: bad coordinates, absurd timestamps and floods are discarded.
 */
export function sanitizeTrail(points: readonly TrailPoint[], nowMs: number): TrailPoint[] {
  const fresh = points
    .filter(valid)
    .filter((p) => p.ts >= nowMs - MAX_TRAIL_AGE_MS && p.ts <= nowMs + MAX_FUTURE_SKEW_MS)
    .map((p) => ({ ...p, ts: Math.min(p.ts, nowMs) }))
    .sort((a, b) => a.ts - b.ts);

  const out: TrailPoint[] = [];
  for (const p of fresh) {
    const last = out[out.length - 1];
    if (last && p.ts - last.ts < MIN_POINT_GAP_MS) {
      // Keep the more accurate of two close points.
      if (p.accuracy < last.accuracy) out[out.length - 1] = p;
      continue;
    }
    out.push(p);
  }
  // Keep the most recent points if the phone was offline for a very long time.
  return out.slice(-MAX_TRAIL_POINTS);
}

/** Minutes, clamped to the range we allow for a planned offline window (max 12 h). */
export function clampQuietMinutes(minutes: number): number {
  if (!Number.isFinite(minutes)) return 0;
  return Math.max(15, Math.min(12 * 60, Math.round(minutes)));
}
