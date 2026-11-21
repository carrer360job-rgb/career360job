import { useCallback, useEffect, useRef, useState } from 'react';
import { getAccessToken } from './supabase';
import { getReport, getReports, resolveReport,
  type JobReport, type ReportDetail, type ReportSummary } from './api';

const reasons: Record<string, string> = {
  fraud: 'Possible fraud', misleading: 'Misleading information',
  duplicate: 'Duplicate job', inappropriate: 'Inappropriate content',
  other: 'Something else',
};
const formatDate = (value: string | null | undefined) => value
  ? new Date(value).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : '—';
const reasonLabel = (value: string) => reasons[value] || value;

export default function ReportsPanel() {
  const [reports, setReports] = useState<JobReport[]>([]);
  const [summary, setSummary] = useState<ReportSummary | null>(null);
  const [total, setTotal] = useState(0);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [status, setStatus] = useState('pending');
  const [reason, setReason] = useState('all');
  const [search, setSearch] = useState('');
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [detail, setDetail] = useState<ReportDetail | null>(null);
  const [decision, setDecision] = useState<'dismissed' | 'job_closed' | null>(null);
  const [notes, setNotes] = useState('');
  const [loading, setLoading] = useState(true);
  const [detailLoading, setDetailLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const listRequestId = useRef(0);

  const load = useCallback(async () => {
    const requestId = ++listRequestId.current;
    setLoading(true); setLoadingMore(false); setError('');
    try {
      const data = await getReports(await getAccessToken(), { status, reason, search: search.trim() });
      if (requestId !== listRequestId.current) return;
      setReports(data.reports); setSummary(data.summary);
      setTotal(data.total); setNextCursor(data.nextCursor);
    } catch (caught) {
      if (requestId === listRequestId.current) setError((caught as Error).message || 'Could not load reports.');
    } finally { if (requestId === listRequestId.current) setLoading(false); }
  }, [status, reason, search]);

  useEffect(() => {
    const timer = setTimeout(() => { void load(); }, search ? 300 : 0);
    return () => { clearTimeout(timer); ++listRequestId.current; };
  }, [load, search]);

  useEffect(() => {
    if (!selectedId) { setDetail(null); return; }
    let active = true;
    setDetailLoading(true); setError(''); setDecision(null); setNotes('');
    void getAccessToken().then((token) => getReport(token, selectedId))
      .then((data) => { if (active) setDetail(data); })
      .catch((caught) => { if (active) setError((caught as Error).message); })
      .finally(() => { if (active) setDetailLoading(false); });
    return () => { active = false; };
  }, [selectedId]);

  const loadMore = async () => {
    if (!nextCursor || loadingMore) return;
    const requestId = listRequestId.current;
    setLoadingMore(true); setError('');
    try {
      const data = await getReports(await getAccessToken(), {
        status, reason, search: search.trim(), cursor: nextCursor,
      });
      if (requestId !== listRequestId.current) return;
      setReports((current) => [...current, ...data.reports]);
      setNextCursor(data.nextCursor); setTotal(data.total);
    } catch (caught) { if (requestId === listRequestId.current) setError((caught as Error).message); }
    finally { if (requestId === listRequestId.current) setLoadingMore(false); }
  };

  const decide = async () => {
    if (!selectedId || !decision || busy) return;
    const trimmed = notes.trim();
    if (decision === 'job_closed' && trimmed.length < 5) {
      setError('Enter at least five characters explaining why the job is being closed.');
      return;
    }
    setBusy(true); setError('');
    try {
      const result = await resolveReport(await getAccessToken(), selectedId, decision, trimmed);
      setSelectedId(null); setDetail(null); setDecision(null); setNotes('');
      setNotice(decision === 'job_closed'
        ? `Job closed and ${result.affectedReports} pending report${result.affectedReports === 1 ? '' : 's'} resolved.`
        : 'Report dismissed. The job remains available.');
      await load();
    } catch (caught) { setError((caught as Error).message); }
    finally { setBusy(false); }
  };

  if (selectedId) {
    const report = detail?.report;
    const job = detail?.job;
    return <section className="reports-workspace">
      <button className="report-back" onClick={() => { setSelectedId(null); setError(''); }}>← Back to reports</button>
      <div className="report-page-heading"><div><p className="eyebrow">REPORT REVIEW</p><h2>{job?.title || 'Reported job'}</h2><p>{job?.companyName || 'Company'} · Submitted {formatDate(report?.createdAt)}</p></div>
        {report && <span className={`report-status report-status-${report.status}`}>{report.status.replace('_', ' ')}</span>}</div>
      {error && <div className="banner error" role="alert">{error}</div>}
      {detailLoading && <div className="empty-state" role="status">Loading report details…</div>}
      {!detailLoading && detail && <div className="report-detail-grid">
        <div className="report-detail-main">
          <section className="report-section"><h3>What was reported</h3>
            <p className="report-reason">{reasonLabel(report!.reason)}</p>
            <p className="report-copy">{report!.details || 'No additional details were provided.'}</p>
            <small>Report ID {report!.id}</small>
          </section>
          <section className="report-section"><h3>Job listing</h3>
            {job ? <>
              <div className="report-facts"><span><b>Status</b>{job.status}</span><span><b>Category</b>{job.category || 'Not provided'}</span><span><b>Location</b>{job.district || 'Not provided'}</span><span><b>Salary</b>{job.salaryText || 'Not specified'}</span></div>
              <p className="report-copy">{job.description || 'No description available.'}</p>
            </> : <p>This job is no longer available.</p>}
          </section>
          <section className="report-section"><h3>Other reports about this job <span>{detail.relatedReports.length}</span></h3>
            {detail.relatedReports.map((item) => <div className="related-report" key={item.id}>
              <strong>{reasonLabel(item.reason)}</strong><span>{item.status.replace('_', ' ')} · {formatDate(item.createdAt)}</span>
              {item.details && <p>{item.details}</p>}
            </div>)}
          </section>
        </div>
        <aside className="report-review-panel">
          <h3>Review decision</h3>
          {report?.status === 'pending' ? <>
            <p>Read the report and listing before taking action. Closing a job removes it from the public feed.</p>
            {!decision ? <div className="report-decision-buttons">
              <button className="row-action" onClick={() => setDecision('dismissed')}>Dismiss report</button>
              <button className="row-action danger-action" onClick={() => setDecision('job_closed')}>Close job</button>
            </div> : <div className="report-confirm">
              <strong>{decision === 'job_closed' ? 'Close this job?' : 'Dismiss this report?'}</strong>
              <p>{decision === 'job_closed' ? 'The job will disappear from the candidate feed. All pending reports for it will be resolved.' : 'The job will stay available to candidates.'}</p>
              <label htmlFor="report-decision-note">{decision === 'job_closed'
                ? 'Reason shared with employer (required)' : 'Internal note (optional)'}</label>
              <textarea id="report-decision-note" value={notes} maxLength={1000} rows={4}
                onChange={(event) => setNotes(event.target.value)} placeholder="Record the reason for this decision" />
              {decision === 'job_closed' && <p>Do not include the reporter's name or contact details.</p>}
              <div className="report-decision-buttons">
                <button className="row-action" disabled={busy} onClick={() => { setDecision(null); setError(''); }}>Cancel</button>
                <button className={`row-action ${decision === 'job_closed' ? 'danger-action' : ''}`} disabled={busy}
                  onClick={() => void decide()}>{busy ? 'Saving…' : decision === 'job_closed' ? 'Confirm close' : 'Confirm dismissal'}</button>
              </div>
            </div>}
          </> : <p>This report was resolved {formatDate(report?.resolvedAt)}.
            {report?.resolutionNotes && <span className="report-resolution-note">Admin note: {report.resolutionNotes}</span>}</p>}
        </aside>
      </div>}
    </section>;
  }

  return <section className="reports-workspace" aria-busy={loading}>
    <div className="operations-toolbar"><div><p className="eyebrow">CAREER360 OPERATIONS</p><h2>Reports & moderation</h2></div>
      <button className="text-button" disabled={loading} onClick={() => void load()}>{loading ? 'Refreshing…' : 'Refresh'}</button></div>
    {error && <div className="banner error" role="alert">{error}</div>}
    {notice && <div className="banner success" role="status">{notice}</div>}
    <div className="report-metrics">
      <div className="stat-card"><span className="stat-label">Pending reports</span><strong className="stat-value">{summary?.pending ?? '—'}</strong></div>
      <div className="stat-card"><span className="stat-label">Dismissed</span><strong className="stat-value">{summary?.dismissed ?? '—'}</strong></div>
      <div className="stat-card"><span className="stat-label">Resolved by closing</span><strong className="stat-value">{summary?.jobClosed ?? '—'}</strong></div>
    </div>
    <div className="reports-filters">
      <div className="reports-tabs" role="group" aria-label="Report status">
        {[['pending', 'Pending'], ['dismissed', 'Dismissed'], ['job_closed', 'Job closed'], ['all', 'All']].map(([value, label]) =>
          <button key={value} className={status === value ? 'active' : ''} aria-pressed={status === value}
            onClick={() => setStatus(value)}>{label}</button>)}
      </div>
      <div className="reports-search-controls">
        <select aria-label="Filter report reason" value={reason} onChange={(event) => setReason(event.target.value)}>
          <option value="all">All reasons</option>{Object.entries(reasons).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
        </select>
        <input aria-label="Search job or company" placeholder="Search job or company" value={search}
          onChange={(event) => setSearch(event.target.value)} />
      </div>
    </div>
    <div className="reports-count">{loading ? 'Loading reports…' : `${total} report${total === 1 ? '' : 's'}`}</div>
    {!loading && !error && reports.length === 0 && <div className="empty-state"><h3>No reports found</h3><p>{status === 'pending' ? 'New job reports will appear here for review.' : 'Try another status or search.'}</p></div>}
    {reports.length > 0 && <div className="reports-list">
      {reports.map((report) => <article className="report-list-row" key={report.id}>
        <div><span className="report-list-reason">{reasonLabel(report.reason)}</span>
          <h3>{report.jobTitle}</h3><p>{report.companyName || 'Company'} · {formatDate(report.createdAt)}</p>
          {report.details && <small>{report.details}</small>}
        </div>
        <div className="report-list-action"><span className={`report-status report-status-${report.status}`}>{report.status.replace('_', ' ')}</span>
          <button className="row-action" onClick={() => setSelectedId(report.id)}>View details</button></div>
      </article>)}
    </div>}
    {nextCursor && <button className="text-button reports-load-more" disabled={loadingMore} onClick={() => void loadMore()}>{loadingMore ? 'Loading…' : 'Load more reports'}</button>}
  </section>;
}
