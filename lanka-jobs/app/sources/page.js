import { db } from '@/lib/db';
import { addCompany, toggleCompany, deleteCompany } from '../actions';
import { ActionForm, Submit, ConfirmSubmit } from '../ui';

export const dynamic = 'force-dynamic';

export default async function Sources() {
  const sql = db();
  const [runs, companies] = await Promise.all([
    sql`select * from runs where finished_at is not null order by id desc limit 1`,
    sql`select * from companies order by name`,
  ]);
  const last = runs[0];
  const boards = last ? Object.entries(last.report.sources || {}).filter(([k]) => !k.startsWith('career:')) : [];

  return (
    <>
      <h1>Sources</h1>
      <p className="sub">
        All sources are checked automatically every 5 minutes.
        {last && <> Last run: {new Date(last.finished_at).toLocaleString('en-GB', { timeZone: 'Asia/Colombo' })} — {last.report.relevant} relevant jobs, {last.new_jobs} new, took {Math.round(last.report.ms / 1000)}s.</>}
      </p>

      <h2>Job boards</h2>
      <div className="tablewrap">
        <table>
          <thead><tr><th>Site</th><th>Status</th><th>Listings read</th></tr></thead>
          <tbody>
            {boards.map(([k, v]) => (
              <tr key={k}>
                <td>{k}</td>
                <td className={v.ok ? 'okc' : 'errc'}>{v.ok ? 'OK' : v.error}</td>
                <td>{v.found ?? '—'}</td>
              </tr>
            ))}
            {!boards.length && <tr><td colSpan={3}>No runs yet.</td></tr>}
          </tbody>
        </table>
      </div>

      <h2>Company career pages ({companies.length})</h2>
      <div className="card">
        <ActionForm action={addCompany}>
          <b>Add a company career page</b>
          <div className="grid2">
            <div>
              <label>Company name</label>
              <input name="name" required placeholder="e.g. Acme Lanka" />
            </div>
            <div>
              <label>Type</label>
              <select name="kind" defaultValue="html">
                <option value="html">Careers web page (any URL)</option>
                <option value="lever">Lever (jobs.lever.co/SLUG)</option>
                <option value="greenhouse">Greenhouse (boards.greenhouse.io/SLUG)</option>
                <option value="workable">Workable (apply.workable.com/SLUG)</option>
                <option value="smartrecruiters">SmartRecruiters (jobs.smartrecruiters.com/SLUG)</option>
                <option value="recruitee">Recruitee (SLUG.recruitee.com)</option>
              </select>
            </div>
          </div>
          <label>Careers page URL, or the SLUG for Lever / Greenhouse / Workable / SmartRecruiters / Recruitee</label>
          <input name="value" required placeholder="https://company.lk/careers  or  company-slug" />
          <div style={{ marginTop: 10 }}>
            <Submit pending="Checking page…">Add &amp; test</Submit>
          </div>
        </ActionForm>
      </div>

      <div className="tablewrap">
        <table>
          <thead><tr><th>Company</th><th>Type</th><th>Status</th><th>Jobs</th><th></th></tr></thead>
          <tbody>
            {companies.map((c) => (
              <tr key={c.id} style={{ opacity: c.enabled ? 1 : 0.5 }}>
                <td>
                  {c.careers_url ? <a href={c.careers_url} target="_blank" rel="noreferrer">{c.name}</a> : c.name}
                </td>
                <td>{c.kind}{c.slug ? `: ${c.slug}` : ''}</td>
                <td className={c.last_error ? 'errc' : 'okc'}>{c.last_error ? c.last_error.slice(0, 80) : c.last_ok ? 'OK' : 'pending'}</td>
                <td>{c.last_count ?? '—'}</td>
                <td>
                  <div className="row">
                    <form action={toggleCompany}>
                      <input type="hidden" name="id" value={c.id} />
                      <button className="btn ghost sm" type="submit">{c.enabled ? 'Pause' : 'Enable'}</button>
                    </form>
                    <form action={deleteCompany}>
                      <input type="hidden" name="id" value={c.id} />
                      <ConfirmSubmit message={`Remove ${c.name}?`}>✕</ConfirmSubmit>
                    </form>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
