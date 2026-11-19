const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

export async function tgCall(token, method, body) {
  const res = await fetch(`https://api.telegram.org/bot${token}/${method}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body || {}),
    cache: 'no-store',
  });
  const data = await res.json();
  if (!data.ok) throw new Error(data.description || 'Telegram error');
  return data.result;
}

export async function sendMessage(token, chatId, html) {
  return tgCall(token, 'sendMessage', { chat_id: chatId, text: html, parse_mode: 'HTML', disable_web_page_preview: true });
}

const LABEL = { intern: '🎓 Intern', associate: '🌱 Associate/Junior', software: '💻 SE', it: '🖥 IT' };

export function formatJobs(jobs, siteUrl) {
  const chunks = [];
  let cur = `🔔 <b>${jobs.length} new job${jobs.length > 1 ? 's' : ''} in Sri Lanka</b>\n`;
  for (const j of jobs) {
    const tags = (j.categories || []).map((c) => LABEL[c]).filter(Boolean).join(' · ');
    const line =
      `\n<b>${esc(j.title)}</b>\n🏢 ${esc(j.company || 'Unknown')}${j.location ? ` · 📍 ${esc(j.location)}` : ''}\n` +
      `${tags ? tags + '\n' : ''}🔗 <a href="${esc(j.url)}">Open on ${esc(j.source)}</a>\n`;
    if ((cur + line).length > 3800) {
      chunks.push(cur);
      cur = '';
    }
    cur += line;
  }
  if (siteUrl) cur += `\n📋 <a href="${esc(siteUrl)}">Open dashboard</a>`;
  chunks.push(cur);
  return chunks;
}
