"use client";

import { Check } from "lucide-react";
import Link from "next/link";
import { orderBy, where } from "firebase/firestore";
import clsx from "clsx";
import { useCollection } from "@/lib/hooks";
import { FALLBACK_PLANS, lkr, Plan } from "@/lib/types";

/** Pricing cards, live from the `plans` collection the admin manages. */
export function PricingCards({ onChoose, currentPlanId, busyPlan }: { onChoose?: (planId: string) => void; currentPlanId?: string; busyPlan?: string | null }) {
  const { data, loading } = useCollection<Plan>("plans", [where("active", "==", true), orderBy("order")], "active-plans");
  // Show monthly plans side by side; yearly variants are offered on the billing page.
  const plans = (loading || data.length === 0 ? FALLBACK_PLANS : data).filter((p) => p.interval !== "year");
  return (
    <div className="grid gap-6 md:grid-cols-3">
      {plans.map((p) => (
        <div key={p.id} className={clsx("card relative flex flex-col p-7", p.highlight && "border-2 border-brand-600 shadow-lg")}>
          {p.highlight && <span className="badge absolute -top-3 left-7 bg-brand-600 text-white">Most popular</span>}
          <h3 className="text-lg font-bold">{p.name}</h3>
          <p className="mt-3">
            <span className="text-4xl font-extrabold tracking-tight">{lkr(p.priceLkr)}</span>
            {p.priceLkr > 0 && <span className="text-slate-500"> / {p.interval}</span>}
          </p>
          <ul className="mt-6 flex-1 space-y-3 text-sm">
            {p.features.map((f) => (
              <li key={f} className="flex gap-2">
                <Check size={18} className="shrink-0 text-safe" />
                {f}
              </li>
            ))}
          </ul>
          <div className="mt-8">
            {onChoose ? (
              currentPlanId === p.id ? (
                <button className="btn-secondary w-full" disabled>Current plan</button>
              ) : p.priceLkr > 0 ? (
                <button className={clsx("w-full", p.highlight ? "btn-primary" : "btn-secondary")} disabled={!!busyPlan} onClick={() => onChoose(p.id)}>
                  {busyPlan === p.id ? "Opening PayHere…" : `Choose ${p.name}`}
                </button>
              ) : null
            ) : (
              <Link href={p.priceLkr > 0 ? "/login/?next=billing" : "/#download"} className={clsx("w-full", p.highlight ? "btn-primary" : "btn-secondary")}>
                {p.priceLkr > 0 ? `Start ${p.name}` : "Get started free"}
              </Link>
            )}
          </div>
        </div>
      ))}
    </div>
  );
}
