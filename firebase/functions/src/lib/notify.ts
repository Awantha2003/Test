import { defineSecret, defineString } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import { db, messaging, familyRef, FieldValue } from "./firebase";

export const SMS_PROVIDER = defineString("SMS_PROVIDER", { default: "none" }); // none | notifylk
export const NOTIFYLK_USER_ID = defineString("NOTIFYLK_USER_ID", { default: "" });
export const NOTIFYLK_SENDER_ID = defineString("NOTIFYLK_SENDER_ID", { default: "NotifyDEMO" });
export const NOTIFYLK_API_KEY = defineSecret("NOTIFYLK_API_KEY");

export type AlertType = "sos" | "enter" | "exit" | "late" | "battery" | "offline" | "speed" | "checkin" | "apps" | "device";

export interface AlertInput {
  type: AlertType;
  childId: string;
  childName: string;
  title: string;
  body: string;
  lat?: number;
  lng?: number;
  placeId?: string;
}

interface Guardian {
  uid: string;
  name: string;
  phone?: string | null;
  smsAlerts?: boolean;
}

export async function guardiansOf(fid: string): Promise<Guardian[]> {
  const snap = await familyRef(fid).collection("members").where("role", "==", "parent").get();
  return snap.docs.map((d) => ({ uid: d.id, ...(d.data() as Omit<Guardian, "uid">) }));
}

/** Create the alert document, then push to every guardian device. Returns the alert id. */
export async function raiseAlert(fid: string, a: AlertInput): Promise<string> {
  const ref = familyRef(fid).collection("alerts").doc();
  await ref.set({
    ...a,
    status: a.type === "sos" ? "open" : "info",
    createdAt: FieldValue.serverTimestamp(),
  });
  try {
    await pushToGuardians(fid, a, ref.id);
  } catch (e) {
    // The alert doc is the source of truth; the apps also listen to it in real time.
    logger.error("push failed", { fid, alertId: ref.id, err: String(e) });
  }
  return ref.id;
}

async function pushToGuardians(fid: string, a: AlertInput, alertId: string): Promise<void> {
  const guardians = await guardiansOf(fid);
  const tokenDocs = (
    await Promise.all(guardians.map((g) => db.collection("users").doc(g.uid).collection("devices").get()))
  ).flatMap((s) => s.docs);
  const tokens = tokenDocs.map((d) => d.get("token") as string).filter(Boolean);
  if (tokens.length === 0) return;

  const isSos = a.type === "sos";
  const res = await messaging.sendEachForMulticast({
    tokens,
    notification: { title: a.title, body: a.body },
    data: {
      type: a.type,
      alertId,
      familyId: fid,
      childId: a.childId,
      ...(a.lat != null && a.lng != null ? { lat: String(a.lat), lng: String(a.lng) } : {}),
    },
    android: {
      priority: "high",
      ttl: isSos ? 0 : 3600 * 1000,
      notification: {
        channelId: isSos ? "sos" : "alerts",
        priority: isSos ? "max" : "high",
        sound: "default",
        visibility: "public",
      },
    },
    apns: {
      headers: { "apns-priority": "10", "apns-push-type": "alert" },
      payload: {
        aps: isSos
          ? // Critical alerts bypass silent mode once Apple grants the entitlement; otherwise iOS treats this as time-sensitive.
            { sound: { critical: true, name: "default", volume: 1 }, "interruption-level": "critical" }
          : { sound: "default", "interruption-level": "time-sensitive" },
      },
    },
    webpush: { headers: { Urgency: "high" } },
  });

  // Clean up tokens for uninstalled apps.
  const dead = res.responses
    .map((r, i) => (!r.success && isDeadTokenError(r.error?.code) ? tokenDocs[i] : null))
    .filter((d): d is NonNullable<typeof d> => d != null);
  await Promise.all(dead.map((d) => d.ref.delete()));
}

function isDeadTokenError(code?: string): boolean {
  return code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token";
}

/** SMS every guardian who has a phone and hasn't opted out. Best effort; never throws. */
export async function smsGuardians(fid: string, message: string): Promise<number> {
  if (SMS_PROVIDER.value() !== "notifylk") return 0;
  const guardians = (await guardiansOf(fid)).filter((g) => g.phone && g.smsAlerts !== false);
  let sent = 0;
  for (const g of guardians) {
    try {
      await sendNotifyLk(g.phone!, message);
      sent++;
    } catch (e) {
      logger.error("sms failed", { fid, uid: g.uid, err: String(e) });
    }
  }
  return sent;
}

/** Notify.lk expects 94XXXXXXXXX (no plus, no leading zero). */
export function toNotifyLkNumber(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  if (digits.startsWith("94")) return digits;
  if (digits.startsWith("0")) return `94${digits.slice(1)}`;
  return digits;
}

async function sendNotifyLk(phone: string, message: string): Promise<void> {
  const body = new URLSearchParams({
    user_id: NOTIFYLK_USER_ID.value(),
    api_key: NOTIFYLK_API_KEY.value(),
    sender_id: NOTIFYLK_SENDER_ID.value(),
    to: toNotifyLkNumber(phone),
    message: message.slice(0, 600),
  });
  const res = await fetch("https://app.notify.lk/api/v1/send", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
    signal: AbortSignal.timeout(8000),
  });
  if (!res.ok) throw new Error(`notify.lk HTTP ${res.status}`);
}
