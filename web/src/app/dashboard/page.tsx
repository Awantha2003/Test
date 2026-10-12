"use client";

import dynamic from "next/dynamic";
import Link from "next/link";
import { useState } from "react";
import { limit, orderBy } from "firebase/firestore";
import { Battery, Clock, Siren } from "lucide-react";
import { useCollection, useDoc } from "@/lib/hooks";
import { useSession } from "@/lib/session";
import { Alert, Child, Family, Live, Place, timeAgo } from "@/lib/types";
import { Empty, PageLoader } from "@/components/ui";
import { AlertRow } from "./alerts/AlertRow";

// Leaflet touches `window`, so the map renders client-side only.
const LiveMap = dynamic(() => import("@/components/LiveMap"), { ssr: false, loading: () => <PageLoader /> });

const STALE_MS = 20 * 60 * 1000;

export default function DashboardHome() {
  const { session } = useSession();
  const fid = session?.familyId;
  const base = fid ? `families/${fid}` : null;
  const family = useDoc<Family>(base);
  const children = useCollection<Child>(base && `${base}/children`);
  const live = useCollection<Live>(base && `${base}/live`);
  const places = useCollection<Place>(base && `${base}/places`);
  const alerts = useCollection<Alert>(base && `${base}/alerts`, [orderBy("createdAt", "desc"), limit(8)], "recent");
  const [focus, setFocus] = useState<[number, number] | null>(null);

  if (children.loading || live.loading) return <PageLoader />;

  const liveById = Object.fromEntries(live.data.map((l) => [l.id, l]));
  const kids = children.data
    .filter((c) => liveById[c.id])
    .map((c) => {
      const l = liveById[c.id];
      return { id: c.id, name: c.name, color: c.color, lat: l.lat, lng: l.lng, accuracy: l.accuracy, stale: !l.ts || Date.now() - l.ts.toMillis() > STALE_MS };
    });
  const openSos = alerts.data.filter((a) => a.type === "sos" && (a.status === "open" || a.status === "acknowledged"));

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-extrabold">{family.data?.name ?? "Your family"}</h1>
        <p className="text-sm text-slate-500">Live locations update automatically.</p>
      </div>

      {openSos.map((a) => (
        <div key={a.id} className="flex items-center gap-4 rounded-2xl bg-sos p-4 text-white shadow-lg">
          <Siren className="shrink-0" />
          <div className="flex-1">
            <p className="font-bold">{a.title}</p>
            <p className="text-sm text-red-100">{a.body} · {timeAgo(a.createdAt)}</p>
          </div>
          {a.lat != null && (
            <button className="btn btn-sm bg-white text-sos" onClick={() => setFocus([a.lat!, a.lng!])}>Show on map</button>
          )}
        </div>
      ))}

      <div className="grid gap-6 lg:grid-cols-3">
        <div className="card h-[520px] overflow-hidden lg:col-span-2">
          <LiveMap kids={kids} places={places.data.map((p) => ({ id: p.id, name: p.name, lat: p.lat, lng: p.lng, radius: p.radius }))} focus={focus} />
        </div>
        <div className="space-y-3">
          {children.data.length === 0 ? (
            <Empty title="No children yet">Add a child from the Rakawala app (Family → Add child).</Empty>
          ) : (
            children.data.map((c) => {
              const l = liveById[c.id];
              const stale = !l?.ts || Date.now() - l.ts.toMillis() > STALE_MS;
              return (
                <button key={c.id} onClick={() => l && setFocus([l.lat, l.lng])} className="card flex w-full items-center gap-3 p-4 text-left transition hover:border-brand-500">
                  <span className="grid h-11 w-11 shrink-0 place-items-center rounded-full border-2 border-white font-extrabold text-white shadow" style={{ background: c.color }}>
                    {c.name.charAt(0).toUpperCase()}
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="font-bold">{c.name}</p>
                    <p className={`flex items-center gap-1 text-xs ${stale ? "text-warn" : "text-slate-500"}`}>
                      <Clock size={12} /> {l ? timeAgo(l.ts) : c.paired ? "waiting for location" : "phone not connected"}
                    </p>
                  </div>
                  {l?.battery != null && (
                    <span className={`flex items-center gap-1 text-xs ${l.battery <= 15 && !l.charging ? "font-bold text-sos" : "text-slate-500"}`}>
                      <Battery size={14} />{l.battery}%
                    </span>
                  )}
                </button>
              );
            })
          )}
          <div className="card p-4">
            <div className="mb-2 flex items-center justify-between">
              <h2 className="font-bold">Recent alerts</h2>
              <Link href="/dashboard/alerts/" className="text-sm font-medium text-brand-600">See all</Link>
            </div>
            {alerts.data.length === 0 ? <p className="py-4 text-sm text-slate-500">All quiet.</p> : alerts.data.map((a) => <AlertRow key={a.id} alert={a} compact />)}
          </div>
        </div>
      </div>
    </div>
  );
}
