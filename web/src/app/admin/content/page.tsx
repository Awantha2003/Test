"use client";

import { doc, setDoc } from "firebase/firestore";
import { useEffect, useState } from "react";
import { db } from "@/lib/firebase";
import { useDoc } from "@/lib/hooks";
import { FALLBACK_CONTENT, SiteContent } from "@/lib/types";
import { Notice, PageLoader } from "@/components/ui";

/** Simple CMS for the public website: hero text, announcement bar and FAQ. */
export default function ContentAdmin() {
  const remote = useDoc<SiteContent>("siteContent/home");
  const [c, setC] = useState<SiteContent | null>(null);
  const [msg, setMsg] = useState<{ tone: "success" | "error"; text: string } | null>(null);

  useEffect(() => {
    if (!remote.loading && c === null) setC({ ...FALLBACK_CONTENT, ...(remote.data ?? {}) });
  }, [remote.loading, remote.data, c]);

  async function save() {
    if (!c) return;
    try {
      await setDoc(doc(db, "siteContent", "home"), {
        heroTitle: c.heroTitle.trim().slice(0, 120),
        heroSubtitle: c.heroSubtitle.trim().slice(0, 300),
        announcement: (c.announcement ?? "").trim().slice(0, 200),
        faq: c.faq.filter((f) => f.q.trim() && f.a.trim()).map((f) => ({ q: f.q.trim().slice(0, 200), a: f.a.trim().slice(0, 1000) })),
      });
      setMsg({ tone: "success", text: "Published. The website updates immediately." });
    } catch (e) {
      setMsg({ tone: "error", text: (e as Error).message });
    }
  }

  if (!c) return <PageLoader />;
  return (
    <div className="max-w-3xl space-y-6">
      <div className="flex items-end justify-between">
        <div>
          <h1 className="text-2xl font-extrabold">Website content</h1>
          <p className="text-sm text-slate-500">Text is rendered as plain text (no HTML) on the public site.</p>
        </div>
        <a className="btn-secondary" href="/" target="_blank" rel="noreferrer">View site</a>
      </div>
      {msg && <Notice tone={msg.tone}>{msg.text}</Notice>}
      <div className="card space-y-4 p-6">
        <div><label className="label">Announcement bar (leave empty to hide)</label><input className="input" value={c.announcement ?? ""} onChange={(e) => setC({ ...c, announcement: e.target.value })} placeholder="e.g. Avurudu offer: 2 months free on yearly plans" /></div>
        <div><label className="label">Hero title</label><input className="input" value={c.heroTitle} onChange={(e) => setC({ ...c, heroTitle: e.target.value })} /></div>
        <div><label className="label">Hero subtitle</label><textarea className="input h-24" value={c.heroSubtitle} onChange={(e) => setC({ ...c, heroSubtitle: e.target.value })} /></div>
      </div>
      <div className="card space-y-4 p-6">
        <div className="flex items-center justify-between">
          <h2 className="font-bold">FAQ</h2>
          <button className="btn-secondary btn-sm" onClick={() => setC({ ...c, faq: [...c.faq, { q: "", a: "" }] })}>Add question</button>
        </div>
        {c.faq.map((f, i) => (
          <div key={i} className="space-y-2 rounded-xl border border-slate-200 p-4">
            <input className="input" placeholder="Question" value={f.q} onChange={(e) => setC({ ...c, faq: c.faq.map((x, j) => (j === i ? { ...x, q: e.target.value } : x)) })} />
            <textarea className="input h-20" placeholder="Answer" value={f.a} onChange={(e) => setC({ ...c, faq: c.faq.map((x, j) => (j === i ? { ...x, a: e.target.value } : x)) })} />
            <button className="text-sm text-sos" onClick={() => setC({ ...c, faq: c.faq.filter((_, j) => j !== i) })}>Remove</button>
          </div>
        ))}
      </div>
      <div className="flex justify-end"><button className="btn-primary" onClick={save}>Publish changes</button></div>
    </div>
  );
}
