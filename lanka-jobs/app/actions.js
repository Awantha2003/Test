'use server';

import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { db, setSetting, getSettings } from '@/lib/db';
import { authToken } from '@/lib/auth';
import { fetchDescription } from '@/lib/describe';
import { tgCall, sendMessage } from '@/lib/telegram';
import { runScan } from '@/lib/scan';
import { scanCompany, KIND_LIST } from '@/lib/sources/careers';

export async function login(_prev, formData) {
  const pw = String(formData.get('password') || '');
  if (!process.env.APP_PASSWORD || pw !== process.env.APP_PASSWORD) return { error: 'Wrong password' };
  (await cookies()).set('lj_auth', await authToken(pw), { httpOnly: true, secure: true, sameSite: 'lax', maxAge: 60 * 60 * 24 * 365, path: '/' });
  redirect('/');
}

export async function logout() {
  (await cookies()).delete('lj_auth');
  redirect('/login');
}

// ---------- Applications ----------
export async function markApplied(formData) {
  const id = Number(formData.get('job_id'));
  const sql = db();
  const [job] = await sql`select * from jobs where id = ${id}`;
  if (!job) return;
  const [exists] = await sql`select id from applications where job_id = ${id}`;
  if (exists) redirect('/applications');
  const full = await fetchDescription(job);
  const description = full && full.length > (job.description || '').length ? full : job.description;
  await sql`insert into applications (job_id, title, company, url, source, description)
    values (${job.id}, ${job.title}, ${job.company}, ${job.url}, ${job.source}, ${description ? description.slice(0, 20000) : null})`;
  revalidatePath('/');
  revalidatePath('/applications');
}

export async function addManualApplication(formData) {
  const title = String(formData.get('title') || '').trim();
  if (!title) return;
  const g = (k) => String(formData.get(k) || '').trim() || null;
  let description = g('description');
  const url = g('url');
  if (!description && url) description = await fetchDescription({ url, source: 'manual' });
  await db()`insert into applications (title, company, url, source, description, notes)
    values (${title}, ${g('company')}, ${url}, 'manual', ${description}, ${g('notes')})`;
  revalidatePath('/applications');
}

export async function updateApplication(formData) {
  const id = Number(formData.get('id'));
  const status = String(formData.get('status') || 'applied');
  const notes = String(formData.get('notes') ?? '');
  const description = formData.get('description');
  const sql = db();
  if (description !== null) {
    await sql`update applications set status = ${status}, notes = ${notes}, description = ${String(description)}, updated_at = now() where id = ${id}`;
  } else {
    await sql`update applications set status = ${status}, notes = ${notes}, updated_at = now() where id = ${id}`;
  }
  revalidatePath('/applications');
}

export async function refetchDescription(formData) {
  const id = Number(formData.get('id'));
  const sql = db();
  const [a] = await sql`select a.*, j.external_id from applications a left join jobs j on j.id = a.job_id where a.id = ${id}`;
  if (!a?.url) return;
  const d = await fetchDescription(a);
  if (d) await sql`update applications set description = ${d.slice(0, 20000)}, updated_at = now() where id = ${id}`;
  revalidatePath('/applications');
}

export async function deleteApplication(formData) {
  await db()`delete from applications where id = ${Number(formData.get('id'))}`;
  revalidatePath('/applications');
  revalidatePath('/');
}

// ---------- Settings / Telegram ----------
export async function saveTelegramToken(_prev, formData) {
  const token = String(formData.get('token') || '').trim();
  if (!token) return { error: 'Paste the bot token from @BotFather' };
  try {
    const me = await tgCall(token, 'getMe');
    await setSetting('telegram_token', token);
    await setSetting('telegram_bot', me.username);
    revalidatePath('/settings');
    return { ok: `Bot @${me.username} saved. Now open Telegram, send /start to @${me.username}, then click “Link my chat”.` };
  } catch (e) {
    return { error: `Invalid token: ${e.message}` };
  }
}

export async function linkTelegramChat() {
  const s = await getSettings();
  if (!s.telegram_token) return { error: 'Save the bot token first' };
  try {
    const updates = await tgCall(s.telegram_token, 'getUpdates', { limit: 50 });
    const msg = [...updates].reverse().find((u) => u.message?.chat?.id);
    if (!msg) return { error: `No messages found. Send /start to @${s.telegram_bot} in Telegram, then try again.` };
    const chatId = String(msg.message.chat.id);
    await setSetting('telegram_chat_id', chatId);
    await sendMessage(s.telegram_token, chatId, '✅ <b>Lanka Jobs connected!</b>\nYou will get new SE / IT / internship jobs here every 5 minutes.');
    revalidatePath('/settings');
    return { ok: `Linked to chat ${msg.message.chat.first_name || msg.message.chat.title || chatId}. Check Telegram for a test message.` };
  } catch (e) {
    return { error: e.message };
  }
}

export async function sendTest() {
  const s = await getSettings();
  if (!s.telegram_token || !s.telegram_chat_id) return { error: 'Telegram not connected' };
  try {
    await sendMessage(s.telegram_token, s.telegram_chat_id, '🔔 Test notification from Lanka Jobs.');
    return { ok: 'Sent!' };
  } catch (e) {
    return { error: e.message };
  }
}

export async function saveNotifyPrefs(formData) {
  await setSetting('notify_mode', String(formData.get('notify_mode') || 'all'));
  await setSetting('notify_keywords', String(formData.get('notify_keywords') || ''));
  await setSetting('block_keywords', String(formData.get('block_keywords') || ''));
  revalidatePath('/settings');
}

export async function scanNow() {
  const r = await runScan();
  revalidatePath('/');
  revalidatePath('/sources');
  return { ok: `Scan done: ${r.relevant} relevant jobs, ${r.new_jobs} new, ${r.notified} sent to Telegram (${Math.round(r.ms / 1000)}s).` };
}

// ---------- Company career pages ----------
export async function addCompany(_prev, formData) {
  const name = String(formData.get('name') || '').trim();
  const kind = String(formData.get('kind') || 'html');
  const value = String(formData.get('value') || '').trim();
  if (!name || !value) return { error: 'Name and URL/slug are required' };
  if (!KIND_LIST.includes(kind)) return { error: 'Unknown type' };
  const c = { name, kind, slug: kind === 'html' ? null : value, careers_url: kind === 'html' ? value : null };
  let count;
  try {
    count = (await scanCompany(c)).length;
  } catch (e) {
    return { error: `Could not read that career page: ${e.message}` };
  }
  await db()`insert into companies (name, kind, slug, careers_url, last_ok, last_count) values (${name}, ${kind}, ${c.slug}, ${c.careers_url}, now(), ${count})`;
  revalidatePath('/sources');
  return { ok: `Added ${name} — found ${count} job link(s) right now.` };
}

export async function toggleCompany(formData) {
  await db()`update companies set enabled = not enabled where id = ${Number(formData.get('id'))}`;
  revalidatePath('/sources');
}

export async function deleteCompany(formData) {
  await db()`delete from companies where id = ${Number(formData.get('id'))}`;
  revalidatePath('/sources');
}
