"use client";

import { orderBy, where } from "firebase/firestore";
import { useEffect, useState } from "react";
import { PricingCards } from "@/components/Pricing";
import { Notice, PageLoader } from "@/components/ui";
import { call } from "@/lib/firebase";
import { useCollection, useDoc } from "@/lib/hooks";
import { buildCheckoutForm } from "@/lib/payhere";
import { useSession } from "@/lib/session";
import { Family } from "@/lib/types";

interface Payment {
  planId: string;
  amount: string;
  currency: string;
  status: string;
  createdAt?: { toDate(): Date };
}

export default function BillingPage() {
  const { session } = useSession();
  const fid = session?.familyId ?? null;
  const family = useDoc<Family>(fid ? `families/${fid}` : null);
  const payments = useCollection<Payment>(fid ? "payments" : null, fid ? [where("familyId", "==", fid), orderBy("createdAt", "desc")] : [], fid ?? "");
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState<string | null>(null);

  useEffect(() => setStatus(new URLSearchParams(window.location.search).get("status")), []);

  async function choose(planId: string) {
    setBusy(planId);
    setError(null);
    try {
      const r = await call<{ checkoutUrl: string; params: Record<string, string> }>("createCheckout", { planId, channel: "web" });
      const form = buildCheckoutForm(document, r.checkoutUrl, r.params);
      document.body.appendChild(form);
      form.submit();
    } catch (e) {
      setError((e as Error).message);
      setBusy(null);
    }
  }

  if (family.loading) return <PageLoader />;
  const f = family.data;
  const owner = f?.ownerUid === session?.user.uid;

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-extrabold">Plan & billing</h1>
      {status === "success" && <Notice tone="success">Payment received. Your plan updates as soon as PayHere confirms it (usually a few seconds).</Notice>}
      {status === "cancelled" && <Notice>Payment cancelled. You have not been charged.</Notice>}
      {error && <Notice tone="error">{error}</Notice>}
      {f && (
        <div className="card flex flex-wrap items-center justify-between gap-4 p-6">
          <div>
            <p className="text-sm text-slate-500">Current plan</p>
            <p className="text-xl font-extrabold capitalize">{f.planId.replace("_", " ")}</p>
            {f.planRenewsAt && (
              <p className="text-sm text-slate-500">
                {f.planStatus === "cancelled" ? "Active until" : "Renews"} {f.planRenewsAt.toDate().toLocaleDateString("en-LK", { dateStyle: "medium" })}
              </p>
            )}
          </div>
          <span className="badge bg-brand-50 capitalize text-brand-700">{f.planStatus}</span>
        </div>
      )}
      {!owner && <Notice>Only the family owner can change the plan.</Notice>}
      <PricingCards onChoose={owner ? choose : undefined} currentPlanId={f?.planId} busyPlan={busy} />
      <div className="card p-6">
        <h2 className="font-bold">Payment history</h2>
        {payments.data.length === 0 ? (
          <p className="mt-3 text-sm text-slate-500">No payments yet.</p>
        ) : (
          <table className="mt-3 w-full text-sm">
            <thead className="text-left text-slate-500"><tr><th className="py-2">Date</th><th>Plan</th><th>Amount</th><th>Status</th></tr></thead>
            <tbody>
              {payments.data.map((p) => (
                <tr key={p.id} className="border-t border-slate-100">
                  <td className="py-2">{p.createdAt?.toDate().toLocaleDateString("en-LK") ?? "-"}</td>
                  <td>{p.planId}</td>
                  <td>{p.currency} {p.amount}</td>
                  <td className="capitalize">{p.status}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
