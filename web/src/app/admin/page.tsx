"use client";

import { useEffect, useState } from "react";
import { call } from "@/lib/firebase";
import { Notice, Stat } from "@/components/ui";

interface Stats {
  families: number;
  payingFamilies: number;
  children: number;
  sosLast24h: number;
  openSos: number;
}

export default function AdminHome() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [seedMsg, setSeedMsg] = useState<string | null>(null);

  const load = () => call<Stats>("adminStats").then(setStats).catch((e: Error) => setError(e.message));
  useEffect(() => {
    load();
    const t = setInterval(load, 60_000);
    return () => clearInterval(t);
  }, []);

  const conversion = stats && stats.families > 0 ? Math.round((stats.payingFamilies / stats.families) * 100) : 0;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-extrabold">Overview</h1>
          <p className="text-sm text-slate-500">Business health at a glance. Refreshes every minute.</p>
        </div>
        <button
          className="btn-secondary"
          onClick={() =>
            call<{ created: number }>("adminSeed")
              .then((r) => setSeedMsg(`Seeded ${r.created} missing item(s).`))
              .catch((e: Error) => setError(e.message))
          }
        >
          Seed default packages & content
        </button>
      </div>
      {error && <Notice tone="error">{error}</Notice>}
      {seedMsg && <Notice tone="success">{seedMsg}</Notice>}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
        <Stat label="Families" value={stats?.families ?? "–"} />
        <Stat label="Paying families" value={stats?.payingFamilies ?? "–"} tone="safe" />
        <Stat label="Conversion" value={stats ? `${conversion}%` : "–"} />
        <Stat label="Children protected" value={stats?.children ?? "–"} />
        <Stat label="Open SOS" value={stats?.openSos ?? "–"} tone={stats && stats.openSos > 0 ? "sos" : "default"} />
      </div>
      <div className="card p-6">
        <h2 className="font-bold">SOS in the last 24 hours: {stats?.sosLast24h ?? "–"}</h2>
        <p className="mt-2 text-sm text-slate-500">
          For privacy, admins see SOS counts only, never children&apos;s locations. Families handle their own SOS. Support can help a family only if they contact us.
        </p>
      </div>
    </div>
  );
}
