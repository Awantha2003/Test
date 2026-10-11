import type { Timestamp } from "firebase/firestore";

export interface Plan {
  name: string;
  priceLkr: number;
  interval: "free" | "month" | "year";
  limits: Record<string, number | boolean>;
  features: string[];
  active: boolean;
  order: number;
  highlight?: boolean;
}

export interface SiteContent {
  heroTitle: string;
  heroSubtitle: string;
  announcement?: string;
  faq: { q: string; a: string }[];
}

export interface Family {
  name: string;
  ownerUid: string;
  planId: string;
  planStatus: string;
  planRenewsAt: Timestamp | null;
  limits: Record<string, number | boolean>;
  createdAt?: Timestamp;
}

export interface Child {
  name: string;
  color: string;
  paired?: boolean;
  deviceName?: string;
}

export interface Live {
  lat: number;
  lng: number;
  accuracy: number;
  speed?: number;
  battery?: number;
  charging?: boolean;
  ts?: Timestamp;
}

export interface Alert {
  type: "sos" | "enter" | "exit" | "late" | "battery" | "offline" | "speed" | "checkin";
  childId: string;
  childName: string;
  title: string;
  body: string;
  lat?: number;
  lng?: number;
  status: string;
  createdAt?: Timestamp;
}

export interface Place {
  name: string;
  type: string;
  lat: number;
  lng: number;
  radius: number;
}

export interface UserDoc {
  role: string | null;
  familyId: string | null;
  displayName?: string;
  email?: string | null;
  disabled?: boolean;
  createdAt?: Timestamp;
}

export interface AuditLog {
  actorUid: string | null;
  action: string;
  target: Record<string, unknown>;
  createdAt?: Timestamp;
}

/** Shown when Firestore has no plans yet (also used for static pre-rendering). */
export const FALLBACK_PLANS: (Plan & { id: string })[] = [
  { id: "free", name: "Free", priceLkr: 0, interval: "free", limits: {}, active: true, order: 0, features: ["1 child", "Live map", "SOS push alerts", "2 safe places", "24h history"] },
  { id: "family_month", name: "Family", priceLkr: 490, interval: "month", limits: {}, active: true, order: 1, highlight: true, features: ["3 children", "10 safe places", "Class arrival schedules", "SMS SOS to guardians", "Voice SOS", "30-day history", "2 co-guardians"] },
  { id: "premium_month", name: "Premium", priceLkr: 990, interval: "month", limits: {}, active: true, order: 2, features: ["6 children", "30 safe places", "50 schedules", "SMS SOS to guardians", "Voice SOS", "90-day history", "5 co-guardians", "Priority support"] },
];

export const FALLBACK_CONTENT: SiteContent = {
  heroTitle: "Know they're safe. Every step of the way.",
  heroSubtitle: "Live location, class-arrival alerts and one-tap SOS for Sri Lankan families.",
  announcement: "",
  faq: [
    { q: "Does my child know they're being shared?", a: "Yes. Rakawala is built for families, not spying. The child's phone always shows that sharing is on." },
    { q: "Does SOS work without mobile data?", a: "Yes. If there's no internet, the child's phone sends an SMS with a map link to guardians." },
    { q: "Is SOS free?", a: "Always. SOS alerts to guardians work on every plan, including Free." },
    { q: "How do I pay?", a: "Visa, Mastercard, Amex, eZ Cash, mCash and Genie via PayHere. Cancel anytime." },
    { q: "Who can see my child's location?", a: "Only the guardians in your family. Not even Rakawala staff can view live locations." },
  ],
};

export function timeAgo(ts?: Timestamp | null): string {
  if (!ts) return "never";
  const s = Math.round((Date.now() - ts.toMillis()) / 1000);
  if (s < 45) return "just now";
  if (s < 3600) return `${Math.round(s / 60)} min ago`;
  if (s < 86400) return `${Math.round(s / 3600)} h ago`;
  return ts.toDate().toLocaleString("en-LK", { day: "numeric", month: "short", hour: "numeric", minute: "2-digit" });
}

export const lkr = (n: number) => (n === 0 ? "Free" : `LKR ${n.toLocaleString("en-LK")}`);
