"use client";

import { limit, orderBy } from "firebase/firestore";
import { useCollection } from "@/lib/hooks";
import { AuditLog } from "@/lib/types";
import { PageLoader } from "@/components/ui";

export default function AuditPage() {
  const logs = useCollection<AuditLog>("auditLogs", [orderBy("createdAt", "desc"), limit(300)], "audit");
  if (logs.loading) return <PageLoader />;
  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-extrabold">Audit log</h1>
        <p className="text-sm text-slate-500">Append-only record of admin actions, pairings, billing events and deletions. Written by the server only.</p>
      </div>
      <div className="card overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500">
            <tr><th className="p-3">When</th><th className="p-3">Action</th><th className="p-3">Actor</th><th className="p-3">Details</th></tr>
          </thead>
          <tbody>
            {logs.data.map((l) => (
              <tr key={l.id} className="border-t border-slate-100 align-top">
                <td className="whitespace-nowrap p-3">{l.createdAt?.toDate().toLocaleString("en-LK") ?? "-"}</td>
                <td className="p-3 font-semibold">{l.action}</td>
                <td className="p-3 font-mono text-xs">{l.actorUid ?? "system"}</td>
                <td className="p-3 font-mono text-xs text-slate-500">{JSON.stringify(l.target)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
