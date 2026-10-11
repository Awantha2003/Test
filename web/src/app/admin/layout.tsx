"use client";

import { FileText, Gauge, Home, Package, ScrollText, Users, Receipt } from "lucide-react";
import { AppShell } from "@/components/AppShell";
import { Notice } from "@/components/ui";
import { useSession } from "@/lib/session";

const nav = [
  { href: "/admin/", label: "Overview", icon: Gauge },
  { href: "/admin/families/", label: "Families", icon: Home },
  { href: "/admin/users/", label: "Users", icon: Users },
  { href: "/admin/plans/", label: "Packages", icon: Package },
  { href: "/admin/payments/", label: "Payments", icon: Receipt },
  { href: "/admin/content/", label: "Website content", icon: FileText },
  { href: "/admin/audit/", label: "Audit log", icon: ScrollText },
];

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const { session } = useSession();
  return (
    <AppShell nav={nav} title="Admin" allow={(s) => s.isAdmin}>
      {session && !session.mfa && (
        <div className="mb-6">
          <Notice tone="error">
            You signed in without a second factor. Admin actions are blocked until you enrol an authenticator app (TOTP) and sign in with it.
          </Notice>
        </div>
      )}
      {children}
    </AppShell>
  );
}
