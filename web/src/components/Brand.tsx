"use client";

import Link from "next/link";
import { ShieldCheck, Menu, X } from "lucide-react";
import { useState } from "react";
import { useSession } from "@/lib/session";

export function Logo({ light = false }: { light?: boolean }) {
  return (
    <Link href="/" className="flex items-center gap-2" aria-label="Rakawala home">
      <span className={`grid h-9 w-9 place-items-center rounded-xl ${light ? "bg-white/15 text-white" : "bg-brand-600 text-white"}`}>
        <ShieldCheck size={20} />
      </span>
      <span className={`text-lg font-extrabold tracking-tight ${light ? "text-white" : "text-slate-900"}`}>Rakawala</span>
    </Link>
  );
}

export function Navbar() {
  const { session } = useSession();
  const [open, setOpen] = useState(false);
  const links = [
    { href: "/#features", label: "Features" },
    { href: "/#how", label: "How it works" },
    { href: "/pricing/", label: "Pricing" },
    { href: "/#faq", label: "FAQ" },
  ];
  return (
    <header className="sticky top-0 z-30 border-b border-slate-200/70 bg-white/80 backdrop-blur">
      <div className="container-page flex h-16 items-center justify-between">
        <Logo />
        <nav className="hidden items-center gap-8 md:flex">
          {links.map((l) => (
            <Link key={l.href} href={l.href} className="text-sm font-medium text-slate-600 hover:text-slate-900">
              {l.label}
            </Link>
          ))}
        </nav>
        <div className="hidden items-center gap-3 md:flex">
          {session ? (
            <Link href={session.isAdmin ? "/admin/" : "/dashboard/"} className="btn-primary">
              {session.isAdmin ? "Admin" : "Open dashboard"}
            </Link>
          ) : (
            <>
              <Link href="/login/" className="btn-secondary">Sign in</Link>
              <Link href="/#download" className="btn-primary">Get the app</Link>
            </>
          )}
        </div>
        <button className="md:hidden" aria-label="Menu" onClick={() => setOpen(!open)}>
          {open ? <X /> : <Menu />}
        </button>
      </div>
      {open && (
        <div className="border-t border-slate-200 bg-white md:hidden">
          <div className="container-page flex flex-col gap-1 py-3">
            {links.map((l) => (
              <Link key={l.href} href={l.href} onClick={() => setOpen(false)} className="rounded-lg px-3 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50">
                {l.label}
              </Link>
            ))}
            <Link href={session ? "/dashboard/" : "/login/"} className="btn-primary mt-2">
              {session ? "Open dashboard" : "Sign in"}
            </Link>
          </div>
        </div>
      )}
    </header>
  );
}

export function Footer() {
  return (
    <footer className="border-t border-slate-200 bg-white">
      <div className="container-page grid gap-8 py-12 md:grid-cols-4">
        <div className="md:col-span-2">
          <Logo />
          <p className="mt-3 max-w-sm text-sm text-slate-500">
            Child safety for Sri Lankan families. Live location, class-arrival alerts and SOS, with privacy by design.
          </p>
          <p className="mt-4 text-sm text-slate-500">
            In an emergency, call <b>119</b> (Police) or <b>1929</b> (Child helpline).
          </p>
        </div>
        <div>
          <h4 className="text-sm font-semibold">Product</h4>
          <ul className="mt-3 space-y-2 text-sm text-slate-500">
            <li><Link href="/#features">Features</Link></li>
            <li><Link href="/pricing/">Pricing</Link></li>
            <li><Link href="/login/">Parent dashboard</Link></li>
          </ul>
        </div>
        <div>
          <h4 className="text-sm font-semibold">Legal</h4>
          <ul className="mt-3 space-y-2 text-sm text-slate-500">
            <li><Link href="/privacy/">Privacy policy</Link></li>
            <li><Link href="/terms/">Terms of service</Link></li>
          </ul>
        </div>
      </div>
      <div className="border-t border-slate-100 py-6 text-center text-xs text-slate-400">© {new Date().getFullYear()} Rakawala. Made in Sri Lanka.</div>
    </footer>
  );
}
