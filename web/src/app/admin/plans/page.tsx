"use client";

import { deleteDoc, doc, orderBy, setDoc } from "firebase/firestore";
import { useState } from "react";
import { db } from "@/lib/firebase";
import { useCollection, WithId } from "@/lib/hooks";
import { lkr, Plan } from "@/lib/types";
import { Notice, PageLoader } from "@/components/ui";

const LIMIT_FIELDS: { key: string; label: string; type: "number" | "bool" }[] = [
  { key: "maxChildren", label: "Children", type: "number" },
  { key: "maxPlaces", label: "Safe places", type: "number" },
  { key: "maxSchedules", label: "Schedules", type: "number" },
  { key: "maxGuardians", label: "Co-guardians", type: "number" },
  { key: "historyDays", label: "History days", type: "number" },
  { key: "smsSos", label: "SMS SOS", type: "bool" },
  { key: "voiceSos", label: "Voice SOS", type: "bool" },
];

const blank: WithId<Plan> = {
  id: "",
  name: "",
  priceLkr: 0,
  interval: "month",
  limits: { maxChildren: 1, maxPlaces: 2, maxSchedules: 1, maxGuardians: 0, historyDays: 1, smsSos: false, voiceSos: false },
  features: [],
  active: true,
  order: 10,
  highlight: false,
};

export default function PlansAdmin() {
  const plans = useCollection<Plan>("plans", [orderBy("order")], "plans");
  const [edit, setEdit] = useState<WithId<Plan> | null>(null);
  const [msg, setMsg] = useState<{ tone: "success" | "error"; text: string } | null>(null);

  async function save(p: WithId<Plan>) {
    if (!/^[a-z0-9_]{1,40}$/.test(p.id)) return setMsg({ tone: "error", text: "ID: lowercase letters, numbers and _ only (e.g. family_month)." });
    const { id, ...data } = p;
    try {
      await setDoc(doc(db, "plans", id), { ...data, priceLkr: Number(data.priceLkr), order: Number(data.order), features: data.features.filter(Boolean) });
      setMsg({ tone: "success", text: `Saved ${p.name}. Website and apps update instantly. Existing subscribers keep their current limits until renewal.` });
      setEdit(null);
    } catch (e) {
      setMsg({ tone: "error", text: (e as Error).message });
    }
  }

  async function remove(id: string) {
    if (!confirm("Delete this package? Prefer marking it inactive so existing subscribers aren't affected.")) return;
    await deleteDoc(doc(db, "plans", id)).catch((e: Error) => setMsg({ tone: "error", text: e.message }));
  }

  if (plans.loading) return <PageLoader />;
  return (
    <div className="space-y-4">
      <div className="flex items-end justify-between">
        <div>
          <h1 className="text-2xl font-extrabold">Packages</h1>
          <p className="text-sm text-slate-500">Prices and limits shown on the website and in the apps. Limits are enforced server-side.</p>
        </div>
        <button className="btn-primary" onClick={() => setEdit({ ...blank })}>New package</button>
      </div>
      {msg && <Notice tone={msg.tone}>{msg.text}</Notice>}
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {plans.data.map((p) => (
          <div key={p.id} className="card p-5">
            <div className="flex items-start justify-between">
              <div>
                <p className="font-bold">{p.name} {p.highlight && <span className="badge ml-1 bg-brand-50 text-brand-700">featured</span>}</p>
                <p className="font-mono text-xs text-slate-400">{p.id}</p>
              </div>
              <span className={`badge ${p.active ? "bg-emerald-100 text-safe" : "bg-slate-100 text-slate-500"}`}>{p.active ? "active" : "inactive"}</span>
            </div>
            <p className="mt-3 text-2xl font-extrabold">{lkr(p.priceLkr)}<span className="text-sm font-normal text-slate-500"> / {p.interval}</span></p>
            <div className="mt-3 flex flex-wrap gap-1">
              {LIMIT_FIELDS.map((f) => (
                <span key={f.key} className="badge bg-slate-100 text-slate-600">{f.label}: {String(p.limits?.[f.key] ?? "-")}</span>
              ))}
            </div>
            <div className="mt-4 flex gap-2">
              <button className="btn-secondary btn-sm" onClick={() => setEdit({ ...p, limits: { ...p.limits }, features: [...p.features] })}>Edit</button>
              <button className="btn-sm btn text-sos hover:bg-red-50" onClick={() => remove(p.id)}>Delete</button>
            </div>
          </div>
        ))}
      </div>

      {edit && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-slate-900/40 p-4" role="dialog" aria-modal="true">
          <div className="card max-h-[90vh] w-full max-w-2xl overflow-y-auto p-6">
            <h2 className="text-lg font-bold">{plans.data.some((p) => p.id === edit.id) ? "Edit package" : "New package"}</h2>
            <div className="mt-4 grid gap-4 sm:grid-cols-2">
              <div><label className="label">ID</label><input className="input font-mono" value={edit.id} disabled={plans.data.some((p) => p.id === edit.id)} onChange={(e) => setEdit({ ...edit, id: e.target.value })} /></div>
              <div><label className="label">Name</label><input className="input" value={edit.name} onChange={(e) => setEdit({ ...edit, name: e.target.value })} /></div>
              <div><label className="label">Price (LKR)</label><input className="input" type="number" min={0} value={edit.priceLkr} onChange={(e) => setEdit({ ...edit, priceLkr: Number(e.target.value) })} /></div>
              <div>
                <label className="label">Billing</label>
                <select className="input" value={edit.interval} onChange={(e) => setEdit({ ...edit, interval: e.target.value as Plan["interval"] })}>
                  <option value="free">Free</option><option value="month">Monthly</option><option value="year">Yearly</option>
                </select>
              </div>
              <div><label className="label">Display order</label><input className="input" type="number" value={edit.order} onChange={(e) => setEdit({ ...edit, order: Number(e.target.value) })} /></div>
              <div className="flex items-end gap-6 pb-3">
                <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={edit.active} onChange={(e) => setEdit({ ...edit, active: e.target.checked })} /> Active</label>
                <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={!!edit.highlight} onChange={(e) => setEdit({ ...edit, highlight: e.target.checked })} /> Featured</label>
              </div>
            </div>
            <h3 className="mt-6 font-semibold">Limits</h3>
            <div className="mt-2 grid gap-3 sm:grid-cols-3">
              {LIMIT_FIELDS.map((f) =>
                f.type === "number" ? (
                  <div key={f.key}>
                    <label className="label">{f.label}</label>
                    <input className="input" type="number" min={0} value={Number(edit.limits[f.key] ?? 0)} onChange={(e) => setEdit({ ...edit, limits: { ...edit.limits, [f.key]: Number(e.target.value) } })} />
                  </div>
                ) : (
                  <label key={f.key} className="flex items-center gap-2 pt-7 text-sm">
                    <input type="checkbox" checked={Boolean(edit.limits[f.key])} onChange={(e) => setEdit({ ...edit, limits: { ...edit.limits, [f.key]: e.target.checked } })} /> {f.label}
                  </label>
                ),
              )}
            </div>
            <h3 className="mt-6 font-semibold">Features (one per line, shown on pricing)</h3>
            <textarea className="input mt-2 h-32" value={edit.features.join("\n")} onChange={(e) => setEdit({ ...edit, features: e.target.value.split("\n") })} />
            <div className="mt-6 flex justify-end gap-2">
              <button className="btn-secondary" onClick={() => setEdit(null)}>Cancel</button>
              <button className="btn-primary" onClick={() => save(edit)}>Save package</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
