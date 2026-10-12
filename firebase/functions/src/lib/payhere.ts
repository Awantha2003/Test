/** PayHere signing and IPN verification. Pure, no Firebase imports. */
import { createHash, timingSafeEqual } from "node:crypto";

const md5Upper = (s: string) => createHash("md5").update(s, "utf8").digest("hex").toUpperCase();

/** PayHere expects amounts formatted with exactly two decimals and no thousands separator. */
export function formatAmount(amount: number): string {
  if (!Number.isFinite(amount) || amount < 0) throw new Error("invalid amount");
  return (Math.round(amount * 100) / 100).toFixed(2);
}

/** hash = UPPER(MD5(merchant_id + order_id + amount + currency + UPPER(MD5(merchant_secret)))) */
export function checkoutHash(
  merchantId: string,
  orderId: string,
  amount: number,
  currency: string,
  merchantSecret: string,
): string {
  return md5Upper(merchantId + orderId + formatAmount(amount) + currency + md5Upper(merchantSecret));
}

export interface PayHereNotify {
  merchant_id: string;
  order_id: string;
  payment_id?: string;
  subscription_id?: string;
  payhere_amount: string;
  payhere_currency: string;
  status_code: string;
  md5sig: string;
  custom_1?: string;
  custom_2?: string;
  method?: string;
  status_message?: string;
  message_type?: string;
  item_rec_status?: string;
  item_rec_date_next?: string;
  item_rec_install_paid?: string;
}

/**
 * md5sig = UPPER(MD5(merchant_id + order_id + payhere_amount + payhere_currency + status_code
 *                    + UPPER(MD5(merchant_secret))))
 * Compared in constant time.
 */
export function verifyNotify(n: PayHereNotify, merchantId: string, merchantSecret: string): boolean {
  if (!n || typeof n.md5sig !== "string" || n.merchant_id !== merchantId) return false;
  const expected = md5Upper(
    n.merchant_id + n.order_id + n.payhere_amount + n.payhere_currency + n.status_code + md5Upper(merchantSecret),
  );
  const a = Buffer.from(expected, "utf8");
  const b = Buffer.from(n.md5sig.toUpperCase(), "utf8");
  return a.length === b.length && timingSafeEqual(a, b);
}

export const PAYHERE_STATUS = {
  SUCCESS: "2",
  PENDING: "0",
  CANCELLED: "-1",
  FAILED: "-2",
  CHARGEDBACK: "-3",
} as const;

export function checkoutUrl(sandbox: boolean): string {
  return sandbox ? "https://sandbox.payhere.lk/pay/checkout" : "https://www.payhere.lk/pay/checkout";
}
