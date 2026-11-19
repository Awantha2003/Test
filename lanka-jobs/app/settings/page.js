import { getSettings } from '@/lib/db';
import { saveTelegramToken, linkTelegramChat, sendTest, saveNotifyPrefs, scanNow, logout } from '../actions';
import { ActionForm, Submit } from '../ui';

export const dynamic = 'force-dynamic';

export default async function Settings() {
  const s = await getSettings();
  const connected = s.telegram_token && s.telegram_chat_id;

  return (
    <>
      <h1>Settings</h1>

      <div className="card">
        <h2 style={{ marginTop: 0 }}>📲 Telegram notifications {connected ? <span className="okc">— connected ✓</span> : <span className="errc">— not connected</span>}</h2>
        <ol style={{ paddingLeft: 18, color: 'var(--muted)' }}>
          <li>Open Telegram, search <b>@BotFather</b>, send <code>/newbot</code>, choose a name. Copy the token it gives you.</li>
          <li>Paste the token below and click <b>Save token</b>.</li>
          <li>Open your new bot in Telegram and press <b>Start</b> (send <code>/start</code>).</li>
          <li>Click <b>Link my chat</b>. You will get a test message.</li>
        </ol>
        <ActionForm action={saveTelegramToken}>
          <label>Bot token {s.telegram_bot && <>(current bot: @{s.telegram_bot})</>}</label>
          <div className="row">
            <input name="token" type="password" placeholder="123456789:AA..." style={{ flex: '1 1 260px', width: 'auto' }} />
            <Submit pending="Checking…">Save token</Submit>
          </div>
        </ActionForm>
        <div className="row" style={{ marginTop: 10, alignItems: 'flex-start' }}>
          <ActionForm action={linkTelegramChat}>
            <Submit className="btn okb" pending="Linking…">Link my chat</Submit>
          </ActionForm>
          <ActionForm action={sendTest}>
            <Submit className="btn ghost" pending="Sending…">Send test message</Submit>
          </ActionForm>
        </div>
      </div>

      <div className="card">
        <h2 style={{ marginTop: 0 }}>🔔 Which jobs should notify me?</h2>
        <form action={saveNotifyPrefs}>
          <label>Mode</label>
          <select name="notify_mode" defaultValue={s.notify_mode || 'all'}>
            <option value="all">All new software / IT / internship jobs</option>
            <option value="entry">Only internships + associate / junior / trainee jobs</option>
            <option value="keywords">Only jobs matching my keywords</option>
          </select>
          <label>Keywords (comma separated, used in “keywords” mode)</label>
          <input name="notify_keywords" defaultValue={s.notify_keywords || 'intern, associate, trainee, junior, software engineer, qa, it'} />
          <label>Never notify if title contains (comma separated)</label>
          <input name="block_keywords" defaultValue={s.block_keywords || 'senior, lead, manager, principal, head of, architect'} />
          <div style={{ marginTop: 10 }}>
            <Submit pending="Saving…">Save preferences</Submit>
          </div>
        </form>
      </div>

      <div className="card">
        <h2 style={{ marginTop: 0 }}>🔄 Scan</h2>
        <p className="sub">Runs automatically every 5 minutes. You can also run it now (takes up to ~40 seconds).</p>
        <ActionForm action={scanNow}>
          <Submit pending="Scanning all sites…">Scan now</Submit>
        </ActionForm>
      </div>

      <form action={logout}>
        <button className="btn ghost" type="submit">Log out</button>
      </form>
    </>
  );
}
