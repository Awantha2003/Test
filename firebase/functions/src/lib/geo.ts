/** Geo maths and geofence evaluation. Pure functions: no Firebase imports, so they are unit-testable. */

export interface LatLng {
  lat: number;
  lng: number;
}

export interface Place extends LatLng {
  id: string;
  name: string;
  radius: number; // metres
  notifyEnter: boolean;
  notifyExit: boolean;
}

const EARTH_RADIUS_M = 6_371_000;
const toRad = (d: number) => (d * Math.PI) / 180;

/** Great-circle distance in metres (haversine). */
export function distanceMeters(a: LatLng, b: LatLng): number {
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** Readings worse than this are too vague to change geofence state. */
export const MAX_USABLE_ACCURACY_M = 250;
/** Extra margin before we declare an exit, so GPS jitter at the boundary doesn't flap. */
export const EXIT_HYSTERESIS_M = 30;

export interface GeofenceResult {
  inside: string[];
  entered: Place[];
  exited: Place[];
}

/**
 * Compare a new position against the family's places.
 *
 * Enter: centre distance <= radius.
 * Exit: centre distance > radius + max(hysteresis, accuracy).
 * Anything in between keeps the previous state. Inaccurate fixes never change state.
 */
export function evaluateGeofences(
  previouslyInside: readonly string[],
  places: readonly Place[],
  point: LatLng & { accuracy: number },
): GeofenceResult {
  const prev = new Set(previouslyInside);
  const knownIds = new Set(places.map((p) => p.id));
  // Drop places that were deleted since last evaluation.
  const inside = new Set([...prev].filter((id) => knownIds.has(id)));

  if (point.accuracy > MAX_USABLE_ACCURACY_M) {
    return { inside: [...inside].sort(), entered: [], exited: [] };
  }

  const entered: Place[] = [];
  const exited: Place[] = [];
  for (const place of places) {
    const d = distanceMeters(place, point);
    const wasInside = inside.has(place.id);
    if (!wasInside && d <= place.radius) {
      inside.add(place.id);
      entered.push(place);
    } else if (wasInside && d > place.radius + Math.max(EXIT_HYSTERESIS_M, point.accuracy)) {
      inside.delete(place.id);
      exited.push(place);
    }
  }
  return { inside: [...inside].sort(), entered, exited };
}

/** m/s → km/h, treating negative (unknown) speed as 0. */
export function toKmh(speedMps: number | undefined | null): number {
  if (speedMps == null || !Number.isFinite(speedMps) || speedMps < 0) return 0;
  return speedMps * 3.6;
}

export function mapsLink(p: LatLng): string {
  return `https://maps.google.com/?q=${p.lat.toFixed(6)},${p.lng.toFixed(6)}`;
}
