// Company career pages. Each company row has a `kind`:
//   lever | greenhouse | workable | smartrecruiters | recruitee | html
import * as cheerio from 'cheerio';
import { fetchText, fetchJson, clean, toDate, htmlToText } from '../http.js';

const LK = /sri lanka|colombo|kandy|galle|jaffna|negombo|malabe|\blk\b|remote|anywhere/i;

async function lever(c) {
  const list = await fetchJson(`https://api.lever.co/v0/postings/${c.slug}?mode=json`);
  return list
    .filter((j) => !j.categories?.location || LK.test(j.categories.location) || c.all_locations)
    .map((j) => ({
      external_id: j.id,
      title: j.text,
      location: j.categories?.location,
      url: j.hostedUrl,
      description: j.descriptionPlain?.slice(0, 4000),
      posted_at: toDate(j.createdAt),
    }));
}

async function greenhouse(c) {
  const data = await fetchJson(`https://boards-api.greenhouse.io/v1/boards/${c.slug}/jobs`);
  return data.jobs
    .filter((j) => LK.test(j.location?.name || '') || c.all_locations)
    .map((j) => ({
      external_id: String(j.id),
      title: j.title,
      location: j.location?.name,
      url: j.absolute_url,
      posted_at: toDate(j.updated_at),
    }));
}

async function workable(c) {
  const data = await fetchJson(`https://apply.workable.com/api/v1/widget/accounts/${c.slug}`);
  return (data.jobs || [])
    .filter((j) => LK.test(`${j.country} ${j.city} ${j.telecommuting ? 'remote' : ''}`) || c.all_locations)
    .map((j) => ({
      external_id: j.shortcode,
      title: j.title,
      location: [j.city, j.country].filter(Boolean).join(', '),
      url: j.url || j.shortlink,
      posted_at: toDate(j.published_on || j.created_at),
    }));
}

async function smartrecruiters(c) {
  const data = await fetchJson(`https://api.smartrecruiters.com/v1/companies/${c.slug}/postings?country=lk&limit=100`);
  return (data.content || []).map((j) => ({
    external_id: j.id,
    title: j.name,
    location: j.location?.fullLocation || j.location?.city,
    url: `https://jobs.smartrecruiters.com/${c.slug}/${j.id}`,
    posted_at: toDate(j.releasedDate),
  }));
}

async function recruitee(c) {
  const data = await fetchJson(`https://${c.slug}.recruitee.com/api/offers/`);
  return (data.offers || [])
    .filter((j) => LK.test(`${j.location} ${j.country} ${j.remote ? 'remote' : ''}`) || c.all_locations)
    .map((j) => ({
      external_id: String(j.id),
      title: j.title,
      location: j.location,
      url: j.careers_url,
      description: htmlToText(j.description).slice(0, 4000),
      posted_at: toDate(j.published_at || j.created_at),
    }));
}

// Generic career page: pick out links whose text looks like a job title.
const ROLE = /(engineer|developer|intern\b|internship|trainee|\bqa\b|quality assurance|analyst|devops|designer|architect|tech(nical)? lead|consultant|specialist|administrator|scientist|programmer|tester|associate|executive|manager)/i;
const NAV = /^(home|about|contact|blog|news|careers?|jobs?|apply|login|sign ?in|read more|learn more|view all|see all|privacy|cookie|terms)$/i;
const JUNK = /(leadership|contact|services?|solutions?|case stud|our team|about us|products?|platform|industr|insights|talk to|book a|demo|webinar|whitepaper|blog|news|events?|partners?|locations?|offices?|don'?t see|general application|open application)/i;
const JOB_URL = /(career|job|vacanc|position|opening|apply|recruit|lever\.co|workable|greenhouse|smartrecruiters|bamboohr|zohorecruit|breezy|teamtailor|myworkdayjobs|hire|\/o\/)/i;

async function html(c) {
  const page = await fetchText(c.careers_url, { timeout: 15000 });
  const $ = cheerio.load(page);
  const base = new URL(c.careers_url);
  const seen = new Set();
  const out = [];
  $('a[href]').each((_, a) => {
    const text = clean($(a).text());
    if (text.length < 4 || text.length > 120 || NAV.test(text) || JUNK.test(text) || !ROLE.test(text)) return;
    let href = $(a).attr('href');
    if (!href || href.startsWith('#') || href.startsWith('mailto:') || href.startsWith('javascript:')) return;
    try {
      href = new URL(href, base).toString();
    } catch {
      return;
    }
    const pth = new URL(href).pathname + new URL(href).hostname;
    if (!JOB_URL.test(pth) || href.replace(/\/$/, '') === c.careers_url.replace(/\/$/, '')) return;
    if (seen.has(href)) return;
    seen.add(href);
    out.push({ external_id: href, title: text, location: 'Sri Lanka', url: href });
  });
  return out;
}

const KINDS = { lever, greenhouse, workable, smartrecruiters, recruitee, html };

export async function scanCompany(c) {
  const fn = KINDS[c.kind];
  if (!fn) throw new Error(`Unknown kind ${c.kind}`);
  const jobs = (await fn(c)).filter((j) => j.title && !JUNK.test(j.title));
  return jobs.map((j) => ({
    ...j,
    title: clean(j.title),
    source: `career:${c.name}`,
    company: c.name,
    external_id: `${c.kind}:${j.external_id}`,
    techSource: c.tech !== false,
  }));
}

export const KIND_LIST = Object.keys(KINDS);
