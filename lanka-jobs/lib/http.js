export const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36';

// Some sites (Cloudflare-protected) block Vercel's IPs. When that happens we
// fetch the page through Supabase (pg_net), which those sites accept.
async function relayFetch(url, timeout) {
  const { db } = await import('./db.js');
  const sql = db();
  const [{ id }] = await sql`select lankajobs.relay_request(${url}) as id`;
  const until = Date.now() + Math.min(timeout + 5000, 25000);
  while (Date.now() < until) {
    await new Promise((r) => setTimeout(r, 700));
    const rows = await sql`select * from lankajobs.relay_result(${id})`;
    if (rows.length) {
      const r = rows[0];
      if (r.error_msg) throw new Error(`relay: ${r.error_msg}`);
      if (r.status_code >= 400) throw new Error(`HTTP ${r.status_code} for ${url} (relay)`);
      return r.content;
    }
  }
  throw new Error(`relay timed out for ${url}`);
}

export async function fetchText(url, opts = {}) {
  try {
    return await directFetch(url, opts);
  } catch (e) {
    const blocked = /HTTP (403|429|503|520|521|522|523|525|526)\b/.test(e.message) || /fetch failed|aborted/i.test(e.message);
    if (!blocked || opts.noRelay || !process.env.DATABASE_URL) throw e;
    return relayFetch(url, opts.timeout || 15000);
  }
}

async function directFetch(url, { timeout = 15000, headers = {} } = {}) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), timeout);
  try {
    const res = await fetch(url, {
      headers: { 'user-agent': UA, accept: 'text/html,application/json;q=0.9,*/*;q=0.8', 'accept-language': 'en-US,en;q=0.9', ...headers },
      signal: ctrl.signal,
      redirect: 'follow',
      cache: 'no-store',
    });
    if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
    return await res.text();
  } finally {
    clearTimeout(t);
  }
}

export async function fetchJson(url, opts) {
  return JSON.parse(await fetchText(url, opts));
}

export function clean(s) {
  return (s || '').replace(/\s+/g, ' ').trim();
}

export function htmlToText(html) {
  if (!html) return '';
  return html
    .replace(/<(script|style|noscript)[\s\S]*?<\/\1>/gi, ' ')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(p|div|li|h[1-6]|tr|ul|ol)>/gi, '\n')
    .replace(/<li[^>]*>/gi, '• ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&#039;|&rsquo;/g, "'")
    .replace(/&bull;/g, '•')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n\s*\n\s*\n+/g, '\n\n')
    .trim();
}

export function toDate(s) {
  if (!s) return null;
  const d = new Date(s);
  return isNaN(d.getTime()) ? null : d;
}
