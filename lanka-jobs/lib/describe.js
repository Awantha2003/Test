// Best-effort fetch of the full job description, saved when you mark a job as applied.
import * as cheerio from 'cheerio';
import { fetchText, fetchJson, htmlToText, clean } from './http.js';

function pageText(html, selectors) {
  const $ = cheerio.load(html);
  $('script,style,noscript,nav,header,footer,iframe').remove();
  for (const sel of selectors) {
    const el = $(sel).first();
    if (el.length && clean(el.text()).length > 80) return htmlToText(el.html());
  }
  return htmlToText($('body').html() || '');
}

export async function fetchDescription(job) {
  const url = job.url;
  try {
    if (job.source === 'xpress.jobs') {
      const d = await fetchJson(`https://xpress.jobs/api/jobs/publishedJob?jobId=${job.external_id}`);
      const parts = [
        d.jobInfo && htmlToText(d.jobInfo),
        d.education && `Education: ${d.education}`,
        d.experience && `Experience: ${d.experience}`,
        d.salaryRange && d.salaryRange !== 'Any' && `Salary: ${d.salaryRange}`,
      ].filter(Boolean);
      if (parts.join('').length > 40) return parts.join('\n\n');
    }
    if (job.source === 'linkedin') {
      const html = await fetchText(`https://www.linkedin.com/jobs-guest/jobs/api/jobPosting/${job.external_id}`);
      return pageText(html, ['.show-more-less-html__markup', '.description__text']);
    }
    if (job.source === 'topjobs.lk') {
      const html = await fetchText(url);
      const $ = cheerio.load(html);
      const imgs = $('img')
        .map((_, i) => $(i).attr('src'))
        .get()
        .filter((s) => s && /logo|banner|\.(jpe?g|png|gif)$/i.test(s) && !/icon|spacer/i.test(s))
        .map((s) => new URL(s, url).toString());
      const text = pageText(html, ['#remark', '.job-description', 'table']);
      return [text, imgs.length ? `\nAdvert image(s):\n${imgs.slice(0, 4).join('\n')}` : ''].join('').trim();
    }
    if (job.source === 'itpro.lk') {
      const html = await fetchText(url);
      return pageText(html, ['.job-description', '.jd', '#job-description', 'main article', 'main']);
    }
    const html = await fetchText(url);
    return pageText(html, ['[class*="description"]', 'article', 'main', '.content']);
  } catch (e) {
    return null;
  }
}
