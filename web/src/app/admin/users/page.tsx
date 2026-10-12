"use client";

import { limit, orderBy } from "firebase/firestore";
import { useMemo, useState } from "react";
import { call } from "@/lib/firebase";
import { useCollection } from "@/lib/hooks";
import { UserDoc } from "@/lib/types";
import { Notice, PageLoader } from "@/components/ui";

export default function UsersPage() {
  const users = useCollection<UserDoc>("users", [orderBy("createdAt", "desc"), limit(1000)], "users");
  const [q, setQ] = useState("");
  const [role, setRole] = useState("all");
  const [msg, setMsg] = useState<{ tone: "success" | "error"; text: string } | null>(null);

  const rows = useMemo(() => {
    const s = q.trim().toLowerCase();
    return users.data.filter(
      (u) =>
        (role === "all" || u.role === role) &&
        (!s || u.id.toLowerCase().includes(s) || (u.email ?? "").toLowerCase().includes(s) || (u.displayName ?? "").toLowerCase().includes(s)),
    );
  }, [users.data, q, role]);

  async function toggle(uid: string, disabled: boolean) {
    if (!confirm(disabled ? "Disable this account and sign it out everywhere?" : "Re-enable this account?")) return;
    try {
      await call("adminSetUserDisabled", { uid, disabled });
      setMsg({ tone: "success", text: disabled ? "Account disabled and signed out." : "Account enabled." });
    } catch (e) {
      setMsg({ tone: "error", text: (e as Error).message });
    }
  }

  if (users.loading) return <PageLoader />;
  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <h1 className="text-2xl font-extrabold">Users <span className="text-slate-400">({users.data.length})</span></h1>
        <div className="flex gap-2">
          <select className="input w-36" value={role} onChange={(e) => setRole(e.target.value)}>
            <option value="all">All roles</option>
            <option value="parent">Guardians</option>
            <option value="child">Child devices</option>
          </select>
          <input className="input w-64" placeholder="Search email, name, uid…" value={q} onChange={(e) => setQ(e.target.value)} />
        </div>
      </div>
      {msg && <Notice tone={msg.tone}>{msg.text}</Notice>}
      <div className="card overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500">
            <tr><th className="p-3">User</th><th className="p-3">Role</th><th className="p-3">Family</th><th className="p-3">Joined</th><th className="p-3" /></tr>
          </thead>
          <tbody>
            {rows.map((u) => (
              <tr key={u.id} className="border-t border-slate-100">
                <td className="p-3">
                  <p className="font-semibold">{u.displayName ?? "-"} {u.disabled && <span className="badge ml-1 bg-red-100 text-sos">disabled</span>}</p>
                  <p className="text-xs text-slate-500">{u.email ?? u.id}</p>
                </td>
                <td className="p-3 capitalize">{u.role ?? "-"}</td>
                <td className="p-3 font-mono text-xs">{u.familyId ?? "-"}</td>
                <td className="p-3">{u.createdAt?.toDate().toLocaleDateString("en-LK") ?? "-"}</td>
                <td className="p-3 text-right">
                  <button className={u.disabled ? "btn-secondary btn-sm" : "btn-danger btn-sm"} onClick={() => toggle(u.id, !u.disabled)}>
                    {u.disabled ? "Enable" : "Disable"}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
