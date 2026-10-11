/** Subscription plans and limit checks. Admins edit plans in Firestore; these are the seed and fallback values. */

export interface PlanLimits {
  maxChildren: number;
  maxPlaces: number;
  maxSchedules: number;
  maxGuardians: number; // parents in addition to the owner
  historyDays: number;
  smsSos: boolean;
  voiceSos: boolean;
}

export interface Plan {
  id: string;
  name: string;
  priceLkr: number;
  interval: "free" | "month" | "year";
  limits: PlanLimits;
  features: string[];
  active: boolean;
  order: number;
  highlight?: boolean;
}

export const FREE_LIMITS: PlanLimits = {
  maxChildren: 1,
  maxPlaces: 2,
  maxSchedules: 1,
  maxGuardians: 0,
  historyDays: 1,
  smsSos: false,
  voiceSos: false,
};

export const DEFAULT_PLANS: Plan[] = [
  {
    id: "free",
    name: "Free",
    priceLkr: 0,
    interval: "free",
    limits: FREE_LIMITS,
    features: ["1 child", "Live map", "SOS push alerts", "2 safe places", "24h history"],
    active: true,
    order: 0,
  },
  {
    id: "family_month",
    name: "Family",
    priceLkr: 490,
    interval: "month",
    limits: { maxChildren: 3, maxPlaces: 10, maxSchedules: 10, maxGuardians: 2, historyDays: 30, smsSos: true, voiceSos: true },
    features: ["3 children", "10 safe places", "Class arrival schedules", "SMS SOS to guardians", "Voice SOS", "30-day history", "2 co-guardians"],
    active: true,
    order: 1,
    highlight: true,
  },
  {
    id: "premium_month",
    name: "Premium",
    priceLkr: 990,
    interval: "month",
    limits: { maxChildren: 6, maxPlaces: 30, maxSchedules: 50, maxGuardians: 5, historyDays: 90, smsSos: true, voiceSos: true },
    features: ["6 children", "30 safe places", "50 schedules", "SMS SOS to guardians", "Voice SOS", "90-day history", "5 co-guardians", "Priority support"],
    active: true,
    order: 2,
  },
  {
    id: "family_year",
    name: "Family (yearly)",
    priceLkr: 4900,
    interval: "year",
    limits: { maxChildren: 3, maxPlaces: 10, maxSchedules: 10, maxGuardians: 2, historyDays: 30, smsSos: true, voiceSos: true },
    features: ["Everything in Family", "2 months free"],
    active: true,
    order: 3,
  },
];

export type LimitKey = "maxChildren" | "maxPlaces" | "maxSchedules" | "maxGuardians";

/** Returns true if adding one more item keeps the family within its plan. */
export function withinLimit(limits: Partial<PlanLimits> | undefined, key: LimitKey, currentCount: number): boolean {
  const max = limits?.[key] ?? FREE_LIMITS[key];
  return currentCount < max;
}

/** Merge stored limits over free defaults so missing keys never grant more than Free. */
export function effectiveLimits(limits: Partial<PlanLimits> | undefined): PlanLimits {
  return { ...FREE_LIMITS, ...(limits ?? {}) };
}

/** Add a billing period to a date (calendar month / year). */
export function addPeriod(from: Date, interval: Plan["interval"], count = 1): Date {
  const d = new Date(from.getTime());
  if (interval === "month") d.setUTCMonth(d.getUTCMonth() + count);
  else if (interval === "year") d.setUTCFullYear(d.getUTCFullYear() + count);
  return d;
}
