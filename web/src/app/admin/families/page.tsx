"use client";

import { limit, orderBy } from "firebase/firestore";
import { useMemo, useState } from "react";
import { call } from "@/lib/firebase";
import { useCollection } from "@/lib/hooks";
import { Family, Plan } from "@/lib/types";
import { Notice, PageLoader } from "@/components/ui";

export default function FamiliesPage() {
  const families = useCollection<Family>("families", [orderBy("createdAt", "desc"), limit(500)], "families");
  const plans = useCollection<Plan>("plans", [orderBy("order")], "plans");
  const [q, setQ] = useState("");
  const [msg, setMsg] = useState<{ tone: "success" | "error"; text: string } | null>(null);

  const rows = useMemo(() => {
    const s = q.trim().toLowerCase();
    return families.data.filter((f) => !s || f.name.toLowerCase().includes(s) || f.id.toLowerCase().includes(s) || f.planId.includes(s));
  }, [families.data, q]);

  async function setPlan(familyId: string, planId: string) {
    const periods = planId === "free" ? 1 : Number(prompt("How many billing periods to grant?", "1") ?? "0");
    if (!periods) return;
    try {
      await call("adminSetFamilyPlan", { familyId, planId, periods });
      setMsg({ tone: "success", text: "Plan updated." });
    } catch (e) {
      setMsg({ tone: "error", text: (e as Error).message });
    }
  }

  if (families.loading) return <PageLoader />;
  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <h1 className="text-2xl font-extrabold">Families <span className="text-slate-400">({families.data.length})</span></h1>
        <input className="input max-w-xs" placeholder="Search name, id or plan…" value={q} onChange={(e) => setQ(e.target.value)} />
      </div>
      {msg && <Notice tone={msg.tone}>{msg.text}</Notice>}
      {families.error && <Notice tone="error">{families.error}</Notice>}
      <div className="card overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500">
            <tr><th className="p-3">Family</th><th className="p-3">Plan</th><th className="p-3">Status</th><th className="p-3">Renews</th><th className="p-3">Created</th><th className="p-3">Change plan</th></tr>
          </thead>
          <tbody>
            {rows.map((f) => (
              <tr key={f.id} className="border-t border-slate-100">
                <td className="p-3"><p className="font-semibold">{f.name}</p><p className="font-mono text-xs text-slate-400">{f.id}</p></td>
                <td className="p-3">{f.planId}</td>
                <td className="p-3"><span className="badge bg-slate-100 capitalize">{f.planStatus}</span></td>
                <td className="p-3">{f.planRenewsAt?.toDate().toLocaleDateString("en-LK") ?? "-"}</td>
                <td className="p-3">{f.createdAt?.toDate().toLocaleDateString("en-LK") ?? "-"}</td>
                <td className="p-3">
                  <select className="input py-2" value="" onChange={(e) => e.target.value && setPlan(f.id, e.target.value)}>
                    <option value="">Select…</option>
                    {(plans.data.length ? plans.data : [{ id: "free", name: "Free" }]).map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
                  </select>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
