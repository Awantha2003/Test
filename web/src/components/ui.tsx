"use client";

import { Loader2 } from "lucide-react";
import clsx from "clsx";

export function Spinner({ className }: { className?: string }) {
  return <Loader2 className={clsx("animate-spin", className)} size={20} />;
}

export function PageLoader() {
  return (
    <div className="grid min-h-[50vh] place-items-center text-slate-400">
      <Spinner />
    </div>
  );
}

export function Empty({ title, children }: { title: string; children?: React.ReactNode }) {
  return (
    <div className="card p-10 text-center">
      <p className="font-semibold">{title}</p>
      {children && <div className="mt-2 text-sm text-slate-500">{children}</div>}
    </div>
  );
}

export function Stat({ label, value, tone = "default" }: { label: string; value: React.ReactNode; tone?: "default" | "sos" | "safe" }) {
  return (
    <div className="card p-5">
      <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{label}</p>
      <p className={clsx("mt-2 text-3xl font-extrabold", tone === "sos" && "text-sos", tone === "safe" && "text-safe")}>{value}</p>
    </div>
  );
}

export function Notice({ tone = "info", children }: { tone?: "info" | "error" | "success"; children: React.ReactNode }) {
  return (
    <div
      role={tone === "error" ? "alert" : "status"}
      className={clsx(
        "rounded-xl px-4 py-3 text-sm",
        tone === "info" && "bg-brand-50 text-brand-900",
        tone === "error" && "bg-red-50 text-red-800",
        tone === "success" && "bg-emerald-50 text-emerald-800",
      )}
    >
      {children}
    </div>
  );
}
