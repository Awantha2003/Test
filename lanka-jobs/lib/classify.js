// Decides whether a job is relevant (software / IT) and tags it with categories.

const RX = {
  intern: /\b(intern|interns|internship|trainee|undergraduate|placement|apprentice)\b/i,
  associate: /\b(associate|junior|jr\.?|graduate|entry[- ]level|fresher|fresh grad)\b/i,
  software:
    /\b(software|programmer|full[- ]?stack|front[- ]?end|back[- ]?end|web developer|mobile developer|app developer|application developer|android|ios developer|flutter|react|angular|vue|node\.?js|java|python|\.net|c#|c\+\+|php|laravel|golang|devops|sre|site reliability|qa engineer|qa intern|qa trainee|software qa|sqa|quality assurance engineer|test automation|automation engineer|sdet|ui\/ux|ux designer|ui engineer|data engineer|data scien\w*|machine learning|ml engineer|ai engineer|ai\/ml|cloud engineer|platform engineer|solutions? architect|software architect|tech lead|technical lead|engineering manager|blockchain|game developer|unity developer|salesforce|odoo|sap developer)\b/i,
  it:
    /\b(information technology|network|system admin|systems? administrator|sysadmin|helpdesk|help desk|technical support|it support|desktop support|cyber ?security|security engineer|soc analyst|database|dba|erp|business analyst|data analyst|bi developer|cloud|infrastructure|computer)\b/i,
};

export function classify(title = '', extra = '') {
  const t = `${title}`;
  const cats = [];
  if (RX.intern.test(t)) cats.push('intern');
  if (RX.associate.test(t)) cats.push('associate');
  if (RX.software.test(t) || (/\b(developer|engineer|qa|tester)\b/i.test(t) && /\b(software|web|mobile|app|IT|computer|code|programming|cloud|api)\b/i.test(extra))) cats.push('software');
  if (RX.it.test(t) || /\b(IT|ICT)\b/.test(t)) cats.push('it');
  return cats;
}

// A job is kept if it is software/IT related. Internships are kept when
// the title or the source context (e.g. an IT category feed) is tech-related.
const NON_TECH =
  /\b(sales|marketing|video|content|social media|graphic|hr|human resources?|talent|recruit\w*|account(ant|ing|s)?|finance|executive assistant|business development|customer (care|service|support)|call cent\w*|admin(istrative)? assistant|receptionist|front desk|driver|rider|legal|procurement|logistics)\b/i;

export function isRelevant(cats, { techSource = false, title = '' } = {}) {
  if (cats.includes('software') || cats.includes('it')) return true;
  if (techSource && !NON_TECH.test(title)) return true;
  return false;
}

export function matchesNotify(job, settings) {
  const mode = settings.notify_mode || 'all'; // all | entry | keywords
  const cats = job.categories || [];
  if (mode === 'entry' && !(cats.includes('intern') || cats.includes('associate'))) return false;
  const kw = (settings.notify_keywords || '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
  if (mode === 'keywords' && kw.length) {
    const hay = `${job.title} ${job.company || ''}`.toLowerCase();
    if (!kw.some((k) => hay.includes(k))) return false;
  }
  const block = (settings.block_keywords || '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
  if (block.length) {
    const hay = `${job.title} ${job.company || ''}`.toLowerCase();
    if (block.some((k) => hay.includes(k))) return false;
  }
  return true;
}
