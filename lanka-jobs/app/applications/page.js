import { db } from '@/lib/db';
import { updateApplication, deleteApplication, addManualApplication, refetchDescription } from '../actions';
import { Submit, ConfirmSubmit } from '../ui';

export const dynamic = 'force-dynamic';

const STATUSES = ['applied', 'interview', 'offer', 'rejected', 'no response'];

export default async function Applications() {
  const apps = await db()`select * from applications order by applied_at desc`;
  const counts = Object.fromEntries(STATUSES.map((s) => [s, apps.filter((a) => a.status === s).length]));

  return (
    <>
      <h1>My applications</h1>
      <p className="sub">Every job you marked as applied, with the job description saved at the time you applied.</p>

      <div className="stats">
        <div className="stat"><b>{apps.length}</b><small>total applied</small></div>
        <div className="stat"><b>{counts.interview}</b><small>interviews</small></div>
        <div className="stat"><b>{counts.offer}</b><small>offers</small></div>
        <div className="stat"><b>{counts.rejected}</b><small>rejected</small></div>
      </div>

      <details className="card">
        <summary>➕ Add an application manually (job not listed here)</summary>
        <form action={addManualApplication}>
          <div className="grid2">
            <div>
              <label>Job title *</label>
              <input name="title" required placeholder="Intern Software Engineer" />
            </div>
            <div>
              <label>Company</label>
              <input name="company" placeholder="WSO2" />
            </div>
          </div>
          <label>Job link (description is fetched automatically if left empty below)</label>
          <input name="url" type="url" placeholder="https://…" />
          <label>Job description</label>
          <textarea name="description" placeholder="Paste the job description here (optional)" />
          <label>Notes</label>
          <input name="notes" placeholder="Applied via email to hr@…" />
          <div style={{ marginTop: 10 }}>
            <Submit pending="Saving…">Save application</Submit>
          </div>
        </form>
      </details>

      {apps.length === 0 ? (
        <div className="empty">No applications yet. On the Jobs page click “✓ Mark applied” after you apply.</div>
      ) : (
        <div className="list">
          {apps.map((a) => (
            <div className="card" key={a.id}>
              <div className="row" style={{ justifyContent: 'space-between' }}>
                <div>
                  <h3 style={{ margin: 0 }}>
                    {a.url ? <a href={a.url} target="_blank" rel="noreferrer">{a.title}</a> : a.title}
                  </h3>
                  <div className="meta" style={{ color: 'var(--muted)', fontSize: 13 }}>
                    🏢 {a.company || '—'} · {a.source || 'manual'} · applied{' '}
                    {new Date(a.applied_at).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })} ·{' '}
                    <b className={`status-${a.status.replace(' ', '-')}`}>{a.status.toUpperCase()}</b>
                  </div>
                </div>
              </div>

              <form action={updateApplication} className="row" style={{ marginTop: 10 }}>
                <input type="hidden" name="id" value={a.id} />
                <select name="status" defaultValue={a.status} style={{ width: 160 }}>
                  {STATUSES.map((s) => (
                    <option key={s} value={s}>{s}</option>
                  ))}
                </select>
                <input name="notes" defaultValue={a.notes || ''} placeholder="Notes (interview date, contact…)" style={{ flex: '1 1 220px', width: 'auto' }} />
                <Submit className="btn sm" pending="…">Save</Submit>
              </form>

              <details>
                <summary>Job description</summary>
                {a.description ? <pre className="descr">{a.description}</pre> : <p className="sub">No description saved.</p>}
                <form action={updateApplication} style={{ marginTop: 8 }}>
                  <input type="hidden" name="id" value={a.id} />
                  <input type="hidden" name="status" value={a.status} />
                  <input type="hidden" name="notes" value={a.notes || ''} />
                  <label>Edit / paste description</label>
                  <textarea name="description" defaultValue={a.description || ''} />
                  <div className="row" style={{ marginTop: 8 }}>
                    <Submit className="btn sm" pending="…">Save description</Submit>
                  </div>
                </form>
              </details>

              <div className="row" style={{ marginTop: 10 }}>
                {a.url && (
                  <form action={refetchDescription}>
                    <input type="hidden" name="id" value={a.id} />
                    <Submit className="btn ghost sm" pending="Fetching…">↻ Re-fetch description</Submit>
                  </form>
                )}
                <form action={deleteApplication}>
                  <input type="hidden" name="id" value={a.id} />
                  <ConfirmSubmit message="Delete this application?">Delete</ConfirmSubmit>
                </form>
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  );
}
