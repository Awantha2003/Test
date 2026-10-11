"use client";

import { BatteryWarning, Gauge, LogIn, LogOut, Siren, AlarmClock, WifiOff, ShieldCheck } from "lucide-react";
import clsx from "clsx";
import { Alert, timeAgo } from "@/lib/types";
import type { WithId } from "@/lib/hooks";

const style: Record<Alert["type"], { icon: typeof Siren; cls: string }> = {
  sos: { icon: Siren, cls: "bg-red-100 text-sos" },
  enter: { icon: LogIn, cls: "bg-emerald-100 text-safe" },
  exit: { icon: LogOut, cls: "bg-blue-100 text-brand-600" },
  late: { icon: AlarmClock, cls: "bg-amber-100 text-warn" },
  battery: { icon: BatteryWarning, cls: "bg-amber-100 text-warn" },
  offline: { icon: WifiOff, cls: "bg-amber-100 text-warn" },
  speed: { icon: Gauge, cls: "bg-amber-100 text-warn" },
  checkin: { icon: ShieldCheck, cls: "bg-emerald-100 text-safe" },
};

export function AlertRow({ alert, compact = false, action }: { alert: WithId<Alert>; compact?: boolean; action?: React.ReactNode }) {
  const s = style[alert.type] ?? style.checkin;
  const Icon = s.icon;
  return (
    <div className={clsx("flex items-start gap-3 py-3", !compact && "border-b border-slate-100 last:border-0")}>
      <span className={clsx("grid h-9 w-9 shrink-0 place-items-center rounded-full", s.cls)}><Icon size={18} /></span>
      <div className="min-w-0 flex-1">
        <p className="text-sm font-semibold">{alert.title}</p>
        {!compact && <p className="text-sm text-slate-600">{alert.body}</p>}
        <p className="text-xs text-slate-400">{timeAgo(alert.createdAt)}</p>
      </div>
      {action}
    </div>
  );
}
