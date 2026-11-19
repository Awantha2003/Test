import { db, getSettings, setSetting } from './db.js';
import { BOARDS } from './sources/boards.js';
import { scanCompany } from './sources/careers.js';
import { classify, isRelevant, matchesNotify } from './classify.js';
import { sendMessage, formatJobs } from './telegram.js';

const withTimeout = (p, ms, label) =>
  Promise.race([p, new Promise((_, rej) => setTimeout(() => rej(new Error(`${label} timed out`)), ms))]);

export async function runScan({ notify = true } = {}) {
  const sql = db();
  const started = Date.now();
  const [run] = await sql`insert into runs default values returning id`;
  const report = {};
  const all = [];

  // 1) Job boards
  const boardTasks = Object.entries(BOARDS).map(async ([name, fn]) => {
    try {
      const jobs = await withTimeout(fn(), 55000, name);
      report[name] = { ok: true, found: jobs.length };
      all.push(...jobs);
    } catch (e) {
      report[name] = { ok: false, error: String(e.message || e).slice(0, 300) };
    }
  });

  // 2) Company career pages
  const companies = await sql`select * from companies where enabled order by id`;
  const companyTasks = companies.map(async (c) => {
    try {
      const jobs = await withTimeout(scanCompany(c), 35000, c.name);
      all.push(...jobs);
      await sql`update companies set last_ok = now(), last_error = null, last_count = ${jobs.length} where id = ${c.id}`;
      report[`career:${c.name}`] = { ok: true, found: jobs.length };
    } catch (e) {
      const msg = String(e.message || e).slice(0, 300);
      await sql`update companies set last_error = ${msg} where id = ${c.id}`;
      report[`career:${c.name}`] = { ok: false, error: msg };
    }
  });

  await Promise.all([...boardTasks, ...companyTasks]);

  // 3) Classify + keep relevant
  const rows = [];
  const irrelevant = [];
  const uniq = new Map();
  for (const j of all) {
    if (!j.title || !j.url || !j.external_id) continue;
    const key = `${j.source}|${j.external_id}`;
    const prev = uniq.get(key);
    if (prev) prev.techSource = prev.techSource || j.techSource;
    else uniq.set(key, { ...j });
  }
  for (const j of uniq.values()) {
    const cats = classify(j.title, j.description || '');
    if (!isRelevant(cats, { techSource: j.techSource })) {
      irrelevant.push(`${j.source}|${String(j.external_id).slice(0, 500)}`);
      continue;
    }
    rows.push({
      source: j.source,
      external_id: String(j.external_id).slice(0, 500),
      title: j.title.slice(0, 300),
      company: (j.company || '').slice(0, 200) || null,
      location: (j.location || '').slice(0, 200) || null,
      url: j.url,
      description: j.description ? String(j.description).slice(0, 4000) : null,
      posted_at: j.posted_at || null,
      closing_at: j.closing_at || null,
      categories: cats,
    });
  }

  // 4) Upsert; collect new ones
  const known = new Set((await sql`select distinct source from jobs`).map((r) => r.source));
  // Most boards use increasing numeric IDs. A listing whose ID is not higher than the
  // highest one we've already stored is an old post we just hadn't seen before.
  const maxIds = Object.fromEntries(
    (await sql`select source, max(external_id::numeric) as m from jobs
               where external_id ~ '^[0-9]{1,30}$' group by source`).map((r) => [r.source, Number(r.m)])
  );
  const isNewer = (j) => {
    const id = Number(String(j.external_id));
    return !Number.isFinite(id) || !maxIds[j.source] || id > maxIds[j.source];
  };
  let inserted = [];
  for (let i = 0; i < rows.length; i += 200) {
    const batch = rows.slice(i, i + 200);
    const res = await sql`
      insert into jobs ${sql(batch, 'source', 'external_id', 'title', 'company', 'location', 'url', 'description', 'posted_at', 'closing_at', 'categories')}
      on conflict (source, external_id) do update set last_seen = now(), title = excluded.title, categories = excluded.categories
      returning id, source, external_id, title, company, location, url, categories, posted_at, (xmax = 0) as is_new`;
    inserted.push(...res.filter((r) => r.is_new));
  }

  // Drop listings that no longer pass the relevance filter (unless you applied to them)
  if (irrelevant.length) {
    await sql`delete from jobs j where (j.source || '|' || j.external_id) = any(${irrelevant})
              and not exists (select 1 from applications a where a.job_id = j.id)`;
  }

  // 5) Notify
  const settings = await getSettings();
  const firstRun = settings.baseline_done !== 'yes';
  let sent = 0;
  if (inserted.length) {
    const ids = inserted.map((r) => r.id);
    if (firstRun) {
      // First ever scan: don't flood Telegram with hundreds of existing jobs.
      await sql`update jobs set notified = true where id = any(${ids})`;
    } else if (notify && settings.telegram_token && settings.telegram_chat_id) {
      const fresh = (j) => !j.posted_at || Date.now() - new Date(j.posted_at).getTime() < 3 * 86400000;
      // A source scanned for the first time (e.g. a newly added career page) only sets a baseline.
      const toSend = inserted.filter((j) => known.has(j.source) && fresh(j) && isNewer(j) && matchesNotify(j, settings));
      if (toSend.length) {
        const site = process.env.SITE_URL || '';
        try {
          for (const chunk of formatJobs(toSend.slice(0, 60), site)) {
            await sendMessage(settings.telegram_token, settings.telegram_chat_id, chunk);
          }
          sent = toSend.length;
        } catch (e) {
          report.telegram = { ok: false, error: String(e.message || e) };
        }
      }
      await sql`update jobs set notified = true where id = any(${ids})`;
    }
  }
  if (firstRun) await setSetting('baseline_done', 'yes');

  const summary = {
    found: all.length,
    relevant: rows.length,
    new_jobs: inserted.length,
    notified: sent,
    baseline: firstRun,
    ms: Date.now() - started,
  };
  await sql`update runs set finished_at = now(), new_jobs = ${inserted.length}, report = ${sql.json({ ...summary, sources: report })} where id = ${run.id}`;
  await sql`delete from runs where started_at < now() - interval '3 days'`;
  return { ...summary, sources: report };
}
