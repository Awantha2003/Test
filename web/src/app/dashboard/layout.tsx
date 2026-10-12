"use client";

import { Bell, CreditCard, Map } from "lucide-react";
import { AppShell } from "@/components/AppShell";

const nav = [
  { href: "/dashboard/", label: "Live map", icon: Map },
  { href: "/dashboard/alerts/", label: "Alerts", icon: Bell },
  { href: "/dashboard/billing/", label: "Plan & billing", icon: CreditCard },
];

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <AppShell nav={nav} title="Family" allow={(s) => s.role === "parent" && !!s.familyId}>
      {children}
    </AppShell>
  );
}
