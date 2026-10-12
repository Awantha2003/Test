"use client";

import { limit, orderBy } from "firebase/firestore";
import { useState } from "react";
import { call } from "@/lib/firebase";
import { useCollection } from "@/lib/hooks";
import { useSession } from "@/lib/session";
import { Alert } from "@/lib/types";
import { Empty, Notice, PageLoader } from "@/components/ui";
import { AlertRow } from "./AlertRow";

export default function AlertsPage() {
  const { session } = useSession();
  const alerts = useCollection<Alert>(session?.familyId ? `families/${session.familyId}/alerts` : null, [orderBy("createdAt", "desc"), limit(200)], "all");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  async function resolve(id: string) {
    if (!confirm("Only mark resolved once you've confirmed your child is safe.")) return;
    setBusy(id);
    setError(null);
    try {
      await call("resolveAlert", { alertId: id, status: "resolved" });
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(null);
    }
  }

  if (alerts.loading) return <PageLoader />;
  return (
    <div className="max-w-3xl space-y-4">
      <h1 className="text-2xl font-extrabold">Alerts</h1>
      {error && <Notice tone="error">{error}</Notice>}
      {alerts.data.length === 0 ? (
        <Empty title="All quiet">Arrivals, departures and safety alerts will appear here.</Empty>
      ) : (
        <div className="card px-5">
          {alerts.data.map((a) => (
            <AlertRow
              key={a.id}
              alert={a}
              action={
                a.type === "sos" && a.status !== "resolved" ? (
                  <button className="btn-danger btn-sm" disabled={busy === a.id} onClick={() => resolve(a.id)}>Mark safe</button>
                ) : null
              }
            />
          ))}
        </div>
      )}
    </div>
  );
}
