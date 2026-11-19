// Sri Lankan job boards: topjobs.lk, xpress.jobs, itpro.lk, jobhub.lk, LinkedIn (Sri Lanka)
import * as cheerio from 'cheerio';
import { fetchText, fetchJson, clean, toDate } from '../http.js';

// ---------- topjobs.lk ----------
// Functional areas: SDQ = Software Development & QA, HNS = IT Hardware/Networks/Systems
const TOPJOBS_FA = ['SDQ', 'HNS'];

export async function topjobs() {
  const out = [];
  for (const fa of TOPJOBS_FA) {
    let html;
    try {
      html = await fetchText(`https://www.topjobs.lk/applicant/vacancybyfunctionalarea.jsp?FA=${fa}`, { timeout: 25000 });
    } catch (e) {
      if (fa === 'SDQ') throw e;
      continue;
    }
    const $ = cheerio.load(html);
    $('tr[id^="tr"]').each((_, el) => {
      const row = $(el);
      const onclick = row.attr('onclick') || '';
      const m = onclick.match(/createAlert\('(\d+)','(\d+)','(\d+)','(\d+)'/);
      if (!m) return;
      const [, rid, ac, jc, ec] = m;
      const title = clean(row.find('h2').first().text());
      const company = clean(row.find('h1').first().text());
      const tds = row.find('td');
      const desc = clean($(tds[3]).text());
      const opening = clean($(tds[4]).text());
      const closing = clean($(tds[5]).text());
      if (!title) return;
      out.push({
        source: 'topjobs.lk',
        external_id: jc,
        title,
        company,
        location: 'Sri Lanka',
        url: `https://www.topjobs.lk/employer/JobAdvertismentServlet?rid=${rid}&ac=${ac}&jc=${jc}&ec=${ec}&pg=applicant/vacancybyfunctionalarea.jsp`,
        description: desc || null,
        posted_at: toDate(opening),
        closing_at: toDate(closing),
        techSource: true,
      });
    });
  }
  return out;
}

// ---------- xpress.jobs ----------
// Sectors: 30 IT-Software/Internet, 139 IT-Hardware/Networks, 27 Internship/Undergraduate
const XPRESS_SECTORS = [
  { id: 30, tech: true },
  { id: 139, tech: true },
  { id: 27, tech: false },
];

const slugify = (s) =>
  (s || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');

const XPRESS_KEYWORDS = ['intern', 'software engineer', 'developer', 'associate software'];

export async function xpress() {
  const out = [];
  // The API returns pages in an unstable order, so we also run keyword searches to cover everything.
  const queries = [
    ...XPRESS_SECTORS.map((s) => ({ q: `sectors=${s.id}`, tech: s.tech })),
    ...XPRESS_KEYWORDS.map((k) => ({ q: `keyword=${encodeURIComponent(k)}`, tech: false })),
  ];
  await Promise.all(queries.map(async (sec) => {
    const list = [];
    for (let page = 1; page <= 2; page++) {
      const part = await fetchJson(`https://xpress.jobs/api/jobs/searchJobs?${sec.q}&page=${page}&pageSize=100`, { timeout: 20000 });
      if (!part?.length) break;
      list.push(...part);
      if (part.length < 100 || list.length >= (part[0].recordCount || 0)) break;
    }
    for (const j of list) {
      out.push({
        source: 'xpress.jobs',
        external_id: String(j.jobId),
        title: clean(j.jobTitle),
        company: clean(j.organizationName),
        location: clean(j.locations),
        url: `https://xpress.jobs/jobs/view/${j.jobId}/${slugify(j.jobTitle + '-' + j.organizationName)}`,
        description: clean(j.overview) || null,
        posted_at: toDate(j.createdDate),
        closing_at: toDate(j.expiryDateOnWebsite),
        techSource: sec.tech,
      });
    }
  }));
  return out;
}

// ---------- itpro.lk ----------
export async function itpro() {
  const out = [];
  const pages = ['https://itpro.lk/jobs/', 'https://itpro.lk/jobs/?page=2', 'https://itpro.lk/'];
  for (const p of pages) {
    let html;
    try {
      html = await fetchText(p);
    } catch (e) {
      if (p === pages[0]) throw e;
      continue;
    }
    const $ = cheerio.load(html);
    $('article.job-card').each((_, el) => {
      const a = $(el).find('a.jcl, a').first();
      const href = a.attr('href') || '';
      const m = href.match(/\/job\/(\d+)\//);
      if (!m) return;
      const title = clean($(el).find('.jc-title').text());
      const company = clean($(el).find('.jc-company').text());
      const la = clean($(el).find('.la').text()).replace(/•/g, '•');
      out.push({
        source: 'itpro.lk',
        external_id: m[1],
        title,
        company,
        location: la.split('•')[0]?.trim() || 'Sri Lanka',
        url: href.startsWith('http') ? href : `https://itpro.lk${href}`,
        description: la || null,
        techSource: true,
      });
    });
  }
  return out;
}

// ---------- jobhub.lk ----------
export async function jobhub() {
  const out = [];
  const html = await fetchText('https://jobhub.lk/en/Sri%20Lanka/search');
  const $ = cheerio.load(html);
  $('a.job-listing').each((_, el) => {
    const href = $(el).attr('href') || '';
    const m = href.match(/\/job\/(\d+)\//) || href.match(/id=(\d+)/);
    if (!m) return;
    out.push({
      source: 'jobhub.lk',
      external_id: m[1],
      title: clean($(el).find('.job-listing-title').text()),
      company: clean($(el).find('.job-listing-company').text()),
      location: 'Sri Lanka',
      url: href.startsWith('http') ? href : `https://jobhub.lk${href.replace(/ /g, '%20')}`,
      description: null,
      techSource: false,
    });
  });
  return out;
}

// ---------- LinkedIn (public guest search, Sri Lanka) ----------
const LI_QUERIES = [
  'software engineer intern',
  'intern software engineer',
  'associate software engineer',
  'trainee software engineer',
  'junior software engineer',
  'IT intern',
  'QA intern',
  'software engineer',
  'IT executive',
];

export async function linkedin() {
  const out = [];
  let ok = 0;
  let lastErr;
  for (const q of LI_QUERIES) {
    const url = `https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search?keywords=${encodeURIComponent(q)}&location=Sri%20Lanka&f_TPR=r604800&start=0`;
    let html;
    try {
      html = await fetchText(url, { timeout: 12000 });
      ok++;
    } catch (e) {
      lastErr = e;
      continue;
    }
    const $ = cheerio.load(html);
    $('div.base-card').each((_, el) => {
      const urn = $(el).attr('data-entity-urn') || '';
      const id = urn.split(':').pop();
      if (!id) return;
      const href = ($(el).find('a.base-card__full-link').attr('href') || '').split('?')[0];
      out.push({
        source: 'linkedin',
        external_id: id,
        title: clean($(el).find('.base-search-card__title').text()),
        company: clean($(el).find('.base-search-card__subtitle').text()),
        location: clean($(el).find('.job-search-card__location').text()),
        url: href || `https://www.linkedin.com/jobs/view/${id}`,
        description: null,
        posted_at: toDate($(el).find('time').attr('datetime')),
        techSource: /software|IT|QA/.test(q),
      });
    });
  }
  if (!ok && lastErr) throw lastErr;
  return out;
}

export const BOARDS = { 'topjobs.lk': topjobs, 'xpress.jobs': xpress, 'itpro.lk': itpro, 'jobhub.lk': jobhub, linkedin };
