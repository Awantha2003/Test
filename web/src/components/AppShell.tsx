"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { LogOut, LucideIcon } from "lucide-react";
import clsx from "clsx";
import { useEffect } from "react";
import { Logo } from "./Brand";
import { PageLoader } from "./ui";
import { logout, Session, useSession } from "@/lib/session";

interface NavItem {
  href: string;
  label: string;
  icon: LucideIcon;
}

/** Authenticated layout with sidebar. `allow` decides who may see it; others are redirected. */
export function AppShell({
  nav,
  allow,
  title,
  children,
}: {
  nav: NavItem[];
  allow: (s: Session) => boolean;
  title: string;
  children: React.ReactNode;
}) {
  const { session, loading } = useSession();
  const router = useRouter();
  const path = usePathname();

  useEffect(() => {
    if (!loading && !session) router.replace("/login/");
  }, [loading, session, router]);

  if (loading || !session) return <PageLoader />;
  if (!allow(session)) {
    return (
      <div className="grid min-h-screen place-items-center p-6 text-center">
        <div className="card max-w-md p-8">
          <h1 className="text-xl font-bold">No access</h1>
          <p className="mt-2 text-sm text-slate-500">
            {session.role === null && !session.isAdmin
              ? "Finish setting up your family in the Rakawala mobile app, then sign in here again."
              : "This area isn't available for your account."}
          </p>
          <button className="btn-secondary mt-6" onClick={() => logout()}>Sign out</button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen md:flex">
      <aside className="border-b border-slate-200 bg-white md:sticky md:top-0 md:h-screen md:w-64 md:shrink-0 md:border-b-0 md:border-r">
        <div className="flex items-center justify-between p-4 md:p-6">
          <Logo />
          <span className="badge bg-brand-50 text-brand-700">{title}</span>
        </div>
        <nav className="flex gap-1 overflow-x-auto px-3 pb-3 md:flex-col md:pb-0">
          {nav.map(({ href, label, icon: Icon }) => {
            const active = href === path || (href !== nav[0].href && path.startsWith(href));
            return (
              <Link
                key={href}
                href={href}
                className={clsx(
                  "flex shrink-0 items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium",
                  active ? "bg-brand-50 text-brand-700" : "text-slate-600 hover:bg-slate-50",
                )}
              >
                <Icon size={18} />
                {label}
              </Link>
            );
          })}
        </nav>
        <div className="hidden p-3 md:absolute md:bottom-0 md:block md:w-64">
          <div className="rounded-xl bg-slate-50 p-3 text-xs text-slate-500">
            Signed in as<br />
            <b className="text-slate-700">{session.user.email}</b>
          </div>
          <button onClick={() => logout()} className="mt-2 flex w-full items-center gap-2 rounded-xl px-3 py-2 text-sm text-slate-600 hover:bg-slate-50">
            <LogOut size={16} /> Sign out
          </button>
        </div>
      </aside>
      <main className="flex-1 p-4 md:p-8">{children}</main>
    </div>
  );
}
