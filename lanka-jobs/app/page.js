import Link from 'next/link';
import { db } from '@/lib/db';
import { markApplied } from './actions';
import { Submit } from './ui';

export const dynamic = 'force-dynamic';

const TABS = [
  { key: '', label: 'All' },
  { key: 'intern', label: '🎓 Internships' },
  { key: 'associate', label: '🌱 Associate / Junior' },
  { key: 'software', label: '💻 Software Eng.' },
  { key: 'it', label: '🖥 IT' },
];
const PAGE = 50;

function ago(d) {
  const s = (Date.now() - new Date(d).getTime()) / 1000;
  if (s < 3600) return `${Math.max(1, Math.round(s / 60))}m ago`;
  if (s < 86400) return `${Math.round(s / 3600)}h ago`;
  return `${Math.round(s / 86400)}d ago`;
}

function qs(params, patch) {
  const p = new URLSearchParams({ ...params, ...patch });
  for (const [k, v] of [...p.entries()]) if (!v) p.delete(k);
  const s = p.toString();
  return s ? `/?${s}` : '/';
}

export default async function Home({ searchParams }) {
  const sp = await searchParams;
  const cat = sp.cat || '';
  const q = (sp.q || '').trim();
  const src = sp.src || '';
  const days = sp.days || '';
  const page = Math.max(1, Number(sp.page) || 1);
  const sql = db();

  const where = sql`
    where (${cat} = '' or ${cat} = any(j.categories))
      and (${q} = '' or j.title ilike ${'%' + q + '%'} or j.company ilike ${'%' + q + '%'})
      and (${src} = '' or j.source = ${src} or (${src} = 'career' and j.source like 'career:%'))
      and (${days} = '' or j.first_seen > now() - (${days || '0'} || ' days')::interval)
      and (j.closing_at is null or j.closing_at > now() - interval '1 day')
      and j.last_seen > now() - interval '21 days'`;

  const [jobs, [{ total }], stats, sources, lastRun] = await Promise.all([
    sql`select j.*, a.id as app_id from jobs j left join applications a on a.job_id = j.id ${where}
        order by j.first_seen desc, j.id desc limit ${PAGE} offset ${(page - 1) * PAGE}`,
    sql`select count(*)::int as total from jobs j ${where}`,
    sql`select
          count(*) filter (where first_seen > now() - interval '24 hours')::int as today,
          count(*) filter (where 'intern' = any(categories))::int as interns,
          count(*) filter (where 'associate' = any(categories))::int as assoc,
          count(*)::int as total
        from jobs where last_seen > now() - interval '21 days'`,
    sql`select case when source like 'career:%' then 'career' else source end as s, count(*)::int as n
        from jobs where last_seen > now() - interval '21 days' group by 1 order by 2 desc`,
    sql`select finished_at from runs where finished_at is not null order by id desc limit 1`,
  ]);
  const st = stats[0];
  const params = { cat, q, src, days };

  return (
    <>
      <h1>Software, IT &amp; internship jobs in Sri Lanka</h1>
      <p className="sub">
        Collected from topjobs.lk, xpress.jobs, itpro.lk, jobhub.lk, LinkedIn and company career pages.
        {lastRun[0] && <> Last checked {ago(lastRun[0].finished_at)}.</>}
      </p>

      <div className="stats">
        <div className="stat"><b>{st.today}</b><small>new in 24h</small></div>
        <div className="stat"><b>{st.interns}</b><small>internships</small></div>
        <div className="stat"><b>{st.assoc}</b><small>associate / junior</small></div>
        <div className="stat"><b>{st.total}</b><small>active jobs</small></div>
      </div>

      <div className="filters">
        {TABS.map((t) => (
          <Link key={t.key} href={qs(params, { cat: t.key, page: '' })} className={`tab ${cat === t.key ? 'on' : ''}`}>
            {t.label}
          </Link>
        ))}
      </div>
      <form className="filters" action="/">
        <input type="hidden" name="cat" value={cat} />
        <input type="search" name="q" defaultValue={q} placeholder="Search title or company (e.g. React, WSO2, QA)…" />
        <select name="src" defaultValue={src}>
          <option value="">All sources</option>
          {sources.map((s) => (
            <option key={s.s} value={s.s}>
              {s.s === 'career' ? 'Company career pages' : s.s} ({s.n})
            </option>
          ))}
        </select>
        <select name="days" defaultValue={days}>
          <option value="">Any time</option>
          <option value="1">Last 24 hours</option>
          <option value="3">Last 3 days</option>
          <option value="7">Last 7 days</option>
        </select>
        <button className="btn" type="submit">Filter</button>
      </form>

      <p className="sub">{total} job{total === 1 ? '' : 's'}</p>

      {jobs.length === 0 ? (
        <div className="empty">No jobs yet — the first scan runs within 5 minutes.</div>
      ) : (
        <div className="list">
          {jobs.map((j) => {
            const isNew = Date.now() - new Date(j.first_seen).getTime() < 86400000;
            return (
              <div className="job" key={j.id}>
                <div>
                  <h3>
                    <a href={j.url} target="_blank" rel="noreferrer">{j.title}</a>
                  </h3>
                  <div className="meta">
                    🏢 {j.company || 'Unknown company'}
                    {j.location ? ` · 📍 ${j.location}` : ''} · {j.source} · found {ago(j.first_seen)}
                    {j.closing_at ? ` · closes ${new Date(j.closing_at).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' })}` : ''}
                  </div>
                  {j.description && <div className="desc">{j.description.slice(0, 220)}</div>}
                  <div className="chips">
                    {isNew && <span className="chip new">NEW</span>}
                    {j.app_id && <span className="chip applied">✓ Applied</span>}
                    {j.categories.map((c) => (
                      <span key={c} className={`chip ${c}`}>{c}</span>
                    ))}
                  </div>
                </div>
                <div className="acts">
                  <a className="btn sm" href={j.url} target="_blank" rel="noreferrer">Open &amp; apply ↗</a>
                  {j.app_id ? (
                    <Link className="btn ghost sm" href="/applications">View application</Link>
                  ) : (
                    <form action={markApplied}>
                      <input type="hidden" name="job_id" value={j.id} />
                      <Submit className="btn ghost sm" pending="Saving…">✓ Mark applied</Submit>
                    </form>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      <div className="pager">
        {page > 1 && <Link className="btn ghost sm" href={qs(params, { page: String(page - 1) })}>← Newer</Link>}
        {page * PAGE < total && <Link className="btn ghost sm" href={qs(params, { page: String(page + 1) })}>Older →</Link>}
      </div>
    </>
  );
}
