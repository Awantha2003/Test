/**
 * Submit PayHere checkout params (signed server-side by `createCheckout`) as a POST form.
 * Only whitelisted keys are posted, and only to PayHere's own checkout hosts.
 */
const ALLOWED_HOSTS = new Set(["www.payhere.lk", "sandbox.payhere.lk"]);
const ALLOWED_KEYS = new Set([
  "merchant_id", "return_url", "cancel_url", "notify_url", "order_id", "items", "currency", "amount",
  "recurrence", "duration", "first_name", "last_name", "email", "phone", "address", "city", "country",
  "custom_1", "custom_2", "hash",
]);

export function buildCheckoutForm(doc: Document, checkoutUrl: string, params: Record<string, string>): HTMLFormElement {
  const url = new URL(checkoutUrl);
  if (url.protocol !== "https:" || !ALLOWED_HOSTS.has(url.host)) throw new Error("Unexpected checkout URL");
  const form = doc.createElement("form");
  form.method = "POST";
  form.action = url.toString();
  for (const [k, v] of Object.entries(params)) {
    if (!ALLOWED_KEYS.has(k)) continue;
    const input = doc.createElement("input");
    input.type = "hidden";
    input.name = k;
    input.value = String(v);
    form.appendChild(input);
  }
  return form;
}
