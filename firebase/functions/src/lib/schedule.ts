/** Arrive-by schedule maths. Pure, no Firebase imports. */

export const DAYS = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"] as const;
export type Day = (typeof DAYS)[number];

export interface LocalTime {
  day: Day;
  minutes: number; // minutes since local midnight
  dateKey: string; // YYYY-MM-DD in the local zone
}

/** Current wall-clock time in an IANA zone, e.g. Asia/Colombo. */
export function localTime(now: Date, timeZone: string): LocalTime {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    weekday: "short",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(now);
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? "";
  const day = get("weekday").toLowerCase().slice(0, 3) as Day;
  return {
    day,
    minutes: Number(get("hour")) * 60 + Number(get("minute")),
    dateKey: `${get("year")}-${get("month")}-${get("day")}`,
  };
}

export function parseHHmm(s: string): number | null {
  const m = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(s);
  return m ? Number(m[1]) * 60 + Number(m[2]) : null;
}

export interface ScheduleLike {
  days: string[];
  arriveBy: string;
  graceMin?: number;
}

/**
 * A schedule is "late" when today is a scheduled day and we're past arriveBy + grace,
 * but still within a 3-hour window (so we don't alert at midnight for a morning class).
 */
export function isLate(s: ScheduleLike, now: LocalTime): boolean {
  if (!s.days.includes(now.day)) return false;
  const due = parseHHmm(s.arriveBy);
  if (due == null) return false;
  const deadline = due + (s.graceMin ?? 10);
  return now.minutes > deadline && now.minutes <= deadline + 180;
}
