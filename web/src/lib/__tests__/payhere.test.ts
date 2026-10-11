// @vitest-environment node
import { describe, expect, it } from "vitest";
import { buildCheckoutForm } from "../payhere";

// Minimal DOM stand-in so the test runs without jsdom.
function fakeDocument() {
  const make = (tag: string) => {
    const el: Record<string, unknown> & { children: unknown[] } = { tag, children: [] };
    el.appendChild = (c: unknown) => el.children.push(c);
    return el;
  };
  return { createElement: make } as unknown as Document;
}

describe("buildCheckoutForm", () => {
  it("posts only whitelisted fields to PayHere", () => {
    const form = buildCheckoutForm(fakeDocument(), "https://sandbox.payhere.lk/pay/checkout", {
      merchant_id: "1211149",
      order_id: "RK1",
      amount: "490.00",
      hash: "ABC",
      evil: "<script>",
    }) as unknown as { method: string; action: string; children: { name: string; value: string }[] };
    expect(form.method).toBe("POST");
    expect(form.action).toBe("https://sandbox.payhere.lk/pay/checkout");
    expect(form.children.map((c) => c.name)).toEqual(["merchant_id", "order_id", "amount", "hash"]);
  });

  it("refuses to post anywhere except PayHere over HTTPS", () => {
    expect(() => buildCheckoutForm(fakeDocument(), "https://evil.example/pay", {})).toThrow();
    expect(() => buildCheckoutForm(fakeDocument(), "http://www.payhere.lk/pay/checkout", {})).toThrow();
  });
});
