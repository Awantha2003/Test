"use client";

import { limit, orderBy } from "firebase/firestore";
import { useCollection } from "@/lib/hooks";
import { PageLoader, Stat } from "@/components/ui";

interface Payment {
  familyId: string;
  planId: string;
  amount: string;
  currency: string;
  status: string;
  method?: string | null;
  createdAt?: { toDate(): Date };
}

export default function PaymentsAdmin() {
  const payments = useCollection<Payment>("payments", [orderBy("createdAt", "desc"), limit(500)], "payments");
  if (payments.loading) return <PageLoader />;
  const paid = payments.data.filter((p) => p.status === "paid");
  const since = Date.now() - 30 * 86400_000;
  const revenue30 = paid.filter((p) => (p.createdAt?.toDate().getTime() ?? 0) > since).reduce((s, p) => s + Number(p.amount), 0);
  const tone = (s: string) => (s === "paid" ? "bg-emerald-100 text-safe" : s === "initiated" || s === "pending" ? "bg-slate-100 text-slate-600" : "bg-red-100 text-sos");

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-extrabold">Payments</h1>
      <div className="grid gap-4 sm:grid-cols-3">
        <Stat label="Revenue (30 days, first payments)" value={`LKR ${revenue30.toLocaleString("en-LK")}`} tone="safe" />
        <Stat label="Paid orders" value={paid.length} />
        <Stat label="Problems" value={payments.data.filter((p) => ["failed", "chargeback", "amount-mismatch"].includes(p.status)).length} tone="sos" />
      </div>
      <div className="card overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500">
            <tr><th className="p-3">Order</th><th className="p-3">Family</th><th className="p-3">Plan</th><th className="p-3">Amount</th><th className="p-3">Method</th><th className="p-3">Status</th><th className="p-3">Date</th></tr>
          </thead>
          <tbody>
            {payments.data.map((p) => (
              <tr key={p.id} className="border-t border-slate-100">
                <td className="p-3 font-mono text-xs">{p.id}</td>
                <td className="p-3 font-mono text-xs">{p.familyId}</td>
                <td className="p-3">{p.planId}</td>
                <td className="p-3">{p.currency} {p.amount}</td>
                <td className="p-3">{p.method ?? "-"}</td>
                <td className="p-3"><span className={`badge ${tone(p.status)}`}>{p.status}</span></td>
                <td className="p-3">{p.createdAt?.toDate().toLocaleString("en-LK") ?? "-"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
