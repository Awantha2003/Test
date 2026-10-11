"use client";

import {
  BatteryWarning, Bell, BookOpen, Clock, Lock, MapPin, Mic, ShieldCheck, Smartphone, Users, WifiOff, Siren,
} from "lucide-react";
import { Footer, Navbar } from "@/components/Brand";
import { PricingCards } from "@/components/Pricing";
import { useDoc } from "@/lib/hooks";
import { FALLBACK_CONTENT, SiteContent } from "@/lib/types";

const features = [
  { icon: MapPin, title: "Live family map", text: "See every child on one map, with battery and 'last updated' so you always know how fresh the location is." },
  { icon: BookOpen, title: "Tuition-class arrival", text: "Set 'should arrive by 3:30 pm on Tue & Thu'. If they haven't reached class, you're alerted." },
  { icon: Siren, title: "Hold-to-SOS", text: "A big SOS button sends their live location to every guardian instantly, by push and SMS." },
  { icon: Mic, title: "Secret voice word", text: "Your child says a secret phrase to trigger SOS hands-free. Recognised on the phone, never recorded." },
  { icon: Bell, title: "Arrive & leave alerts", text: "Know when they reach school, leave class or get home, without calling them." },
  { icon: WifiOff, title: "Works without data", text: "No internet? The child's phone sends an SMS with a map link to you." },
  { icon: BatteryWarning, title: "Battery & offline alerts", text: "Get told when the phone is low or stops sharing, before it's a mystery." },
  { icon: Users, title: "Both parents, grandparents", text: "Invite co-guardians so every adult who cares gets the alerts." },
];

const steps = [
  { icon: Smartphone, title: "Install on your phone", text: "Create your guardian account and family in a minute." },
  { icon: Lock, title: "Pair your child's phone", text: "Install Rakawala on their phone and enter the one-time code you see." },
  { icon: ShieldCheck, title: "Add places & schedules", text: "Home, school, tuition classes. We'll handle the rest." },
];

export default function Home() {
  const { data } = useDoc<SiteContent>("siteContent/home");
  const content = { ...FALLBACK_CONTENT, ...(data ?? {}) };

  return (
    <>
      {content.announcement ? (
        <div className="bg-brand-900 px-4 py-2 text-center text-sm text-white">{content.announcement}</div>
      ) : null}
      <Navbar />
      <main>
        {/* Hero */}
        <section className="relative overflow-hidden bg-gradient-to-br from-brand-900 via-brand-700 to-brand-500 text-white">
          <div className="container-page grid items-center gap-12 py-20 md:grid-cols-2 md:py-28">
            <div>
              <span className="badge bg-white/15 text-white">🇱🇰 Built for Sri Lankan families</span>
              <h1 className="mt-5 text-4xl font-extrabold leading-tight tracking-tight md:text-6xl">{content.heroTitle}</h1>
              <p className="mt-5 max-w-lg text-lg text-blue-100">{content.heroSubtitle}</p>
              <div id="download" className="mt-8 flex flex-wrap gap-3">
                <a href="#" className="btn bg-white text-brand-900 hover:bg-blue-50">Get it on Google Play</a>
                <a href="#" className="btn border border-white/40 text-white hover:bg-white/10">Download on the App Store</a>
              </div>
              <p className="mt-4 text-sm text-blue-200">Free for one child · SOS is free on every plan</p>
            </div>
            <div className="relative mx-auto w-full max-w-sm">
              <div className="rounded-[2.5rem] border-8 border-slate-900 bg-slate-900 shadow-2xl">
                <div className="overflow-hidden rounded-[2rem] bg-white text-slate-900">
                  <div className="h-56 bg-[radial-gradient(circle_at_30%_40%,#DBE6FE,transparent_40%),radial-gradient(circle_at_70%_70%,#D1FAE5,transparent_35%)] p-4">
                    <div className="flex h-full items-center justify-around">
                      <span className="grid h-12 w-12 place-items-center rounded-full border-4 border-white bg-pink-600 font-extrabold text-white shadow-lg">N</span>
                      <span className="grid h-12 w-12 place-items-center rounded-full border-4 border-white bg-blue-600 font-extrabold text-white shadow-lg">S</span>
                    </div>
                  </div>
                  <div className="space-y-3 p-4">
                    <div className="flex items-center gap-3 rounded-xl border border-slate-200 p-3">
                      <span className="grid h-9 w-9 place-items-center rounded-full bg-emerald-100 text-safe"><BookOpen size={18} /></span>
                      <div className="text-sm"><b>Nimali arrived at Maths class</b><p className="text-slate-500">3:24 pm · battery 76%</p></div>
                    </div>
                    <div className="flex items-center gap-3 rounded-xl border border-slate-200 p-3">
                      <span className="grid h-9 w-9 place-items-center rounded-full bg-blue-100 text-brand-600"><Clock size={18} /></span>
                      <div className="text-sm"><b>Sahan left school</b><p className="text-slate-500">1:35 pm · on the way home</p></div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* Features */}
        <section id="features" className="container-page py-20">
          <div className="mx-auto max-w-2xl text-center">
            <h2 className="text-3xl font-extrabold tracking-tight md:text-4xl">Everything you worry about, covered</h2>
            <p className="mt-4 text-slate-600">Designed around real days: school, tuition, the bus and the walk home.</p>
          </div>
          <div className="mt-14 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
            {features.map(({ icon: Icon, title, text }) => (
              <div key={title} className="card p-6">
                <span className="grid h-11 w-11 place-items-center rounded-xl bg-brand-50 text-brand-600"><Icon size={22} /></span>
                <h3 className="mt-4 font-bold">{title}</h3>
                <p className="mt-2 text-sm text-slate-600">{text}</p>
              </div>
            ))}
          </div>
        </section>

        {/* How it works */}
        <section id="how" className="bg-white py-20">
          <div className="container-page">
            <h2 className="text-center text-3xl font-extrabold tracking-tight md:text-4xl">Set up in 3 minutes</h2>
            <div className="mt-14 grid gap-8 md:grid-cols-3">
              {steps.map(({ icon: Icon, title, text }, i) => (
                <div key={title} className="text-center">
                  <span className="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-brand-600 text-white"><Icon size={26} /></span>
                  <p className="mt-4 text-xs font-bold uppercase tracking-wider text-brand-600">Step {i + 1}</p>
                  <h3 className="mt-1 text-lg font-bold">{title}</h3>
                  <p className="mt-2 text-sm text-slate-600">{text}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* Privacy */}
        <section className="container-page py-20">
          <div className="card grid gap-8 p-8 md:grid-cols-2 md:p-12">
            <div>
              <h2 className="text-3xl font-extrabold tracking-tight">Safety without spying</h2>
              <p className="mt-4 text-slate-600">
                Your children&apos;s location is the most sensitive data there is. We designed Rakawala like a bank designs a vault.
              </p>
            </div>
            <ul className="space-y-3 text-sm">
              {[
                "Only guardians in your family can see locations. Not even our staff.",
                "Your child always sees that sharing is on. No hidden tracking.",
                "History auto-deletes (1–90 days by plan). Delete everything anytime.",
                "Voice SOS runs on the phone. Audio is never recorded or uploaded.",
                "Encrypted in transit and at rest. App-integrity checks block fake apps.",
                "Compliant with Sri Lanka's Personal Data Protection Act.",
              ].map((t) => (
                <li key={t} className="flex gap-3"><ShieldCheck className="shrink-0 text-safe" size={20} />{t}</li>
              ))}
            </ul>
          </div>
        </section>

        {/* Pricing */}
        <section id="pricing" className="bg-white py-20">
          <div className="container-page">
            <div className="mx-auto max-w-2xl text-center">
              <h2 className="text-3xl font-extrabold tracking-tight md:text-4xl">Simple pricing in rupees</h2>
              <p className="mt-4 text-slate-600">Pay with card, eZ Cash, mCash or Genie. Cancel anytime.</p>
            </div>
            <div className="mt-12"><PricingCards /></div>
          </div>
        </section>

        {/* FAQ */}
        <section id="faq" className="container-page py-20">
          <h2 className="text-center text-3xl font-extrabold tracking-tight md:text-4xl">Questions parents ask</h2>
          <div className="mx-auto mt-10 max-w-3xl space-y-3">
            {content.faq.map((f) => (
              <details key={f.q} className="card group p-5">
                <summary className="cursor-pointer list-none font-semibold marker:hidden">{f.q}</summary>
                <p className="mt-3 text-sm text-slate-600">{f.a}</p>
              </details>
            ))}
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
