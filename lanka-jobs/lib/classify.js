// Decides whether a job is relevant (software / IT) and tags it with categories.

const RX = {
  intern: /\b(intern|interns|internship|trainee|undergraduate|placement|apprentice)\b/i,
  associate: /\b(associate|junior|jr\.?|graduate|entry[- ]level|fresher|fresh grad)\b/i,
  software:
    /\b(software|developer|programmer|full[- ]?stack|front[- ]?end|back[- ]?end|mobile app|android|ios|flutter|react|angular|node|java|python|\.net|php|golang|devops|sre|qa|quality assurance|test automation|sdet|tester|ui\/ux|ux|data engineer|data scien|machine learning|ml engineer|ai engineer|cloud engineer|web developer|solutions? architect|tech lead|technical lead|engineering manager)\b/i,
  it:
    /\b(information technology|network|system admin|systems? administrator|sysadmin|helpdesk|help desk|technical support|it support|desktop support|cyber ?security|security engineer|soc analyst|database|dba|erp|business analyst|data analyst|bi developer|cloud|infrastructure|computer)\b/i,
};

export function classify(title = '', extra = '') {
  const t = `${title}`;
  const cats = [];
  if (RX.intern.test(t)) cats.push('intern');
  if (RX.associate.test(t)) cats.push('associate');
  if (RX.software.test(t) || /\bengineer\b/i.test(t) && RX.software.test(extra)) cats.push('software');
  if (RX.it.test(t) || /\b(IT|ICT)\b/.test(t)) cats.push('it');
  return cats;
}

// A job is kept if it is software/IT related. Internships are kept when
// the title or the source context (e.g. an IT category feed) is tech-related.
export function isRelevant(cats, { techSource = false } = {}) {
  if (cats.includes('software') || cats.includes('it')) return true;
  if (techSource) return true;
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
