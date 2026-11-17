import { useCallback, useEffect, useRef, useState } from 'react';
import { auth } from './supabase';
import { ApiError, getReports, listPayments, listUsers, resolveReport,
  reconcilePaymentRefund, refundPayment, setUserDisabled, type AdminUser, type JobReport, type PaymentRecord, type ReportSummary } from './api';

type Props = { kind: 'users' | 'payments' | 'reports' };
const money = (paise: number) => new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR' }).format(paise / 100);
const date = (value: string | null | undefined) => value ? new Date(value).toLocaleString() : '—';

export default function OperationsPanels({ kind }: Props) {
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [payments, setPayments] = useState<PaymentRecord[]>([]);
  const [reports, setReports] = useState<JobReport[]>([]);
  const [summary, setSummary] = useState<ReportSummary | null>(null);
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('all');
  const [nextPage, setNextPage] = useState<string | null>(null);
  const [nextPaymentCursor, setNextPaymentCursor] = useState<string | null>(null);
  const [nextReportCursor, setNextReportCursor] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasLoaded, setHasLoaded] = useState(false);
  const requestId = useRef(0);
  const [available, setAvailable] = useState(true);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const token = async () => {
    if (!auth?.currentUser) throw new Error('Sign in again to continue.');
    return auth.currentUser.getIdToken();
  };
  const load = useCallback(async () => {
    const currentRequest = ++requestId.current;
    setLoading(true); setError('');
    try {
      const idToken = await token();
      if (currentRequest !== requestId.current) return;
      if (kind === 'users') { const data = await listUsers(idToken, search); if (currentRequest !== requestId.current) return; setUsers(data.users); setNextPage(data.nextPageToken); setAvailable(true); }
      if (kind === 'payments') { const data = await listPayments(idToken, status); if (currentRequest !== requestId.current) return; setPayments(data.payments); setNextPaymentCursor(data.nextCursor); setAvailable(data.available !== false); }
      if (kind === 'reports') { const data = await getReports(idToken); if (currentRequest !== requestId.current) return; setReports(data.reports); setSummary(data.summary); setNextReportCursor(data.nextCursor); setAvailable(data.available !== false); }
    } catch (caught) {
      if (currentRequest === requestId.current) setError(caught instanceof ApiError ? caught.message : (caught as Error).message);
    } finally { if (currentRequest === requestId.current) { setLoading(false); setHasLoaded(true); } }
  }, [kind, search, status]);
  useEffect(() => {
    const timer = setTimeout(() => { void load(); }, kind === 'users' && search ? 250 : 0);
    return () => { clearTimeout(timer); ++requestId.current; };
  }, [load, kind, search]);
  const act = async (work: () => Promise<unknown>, message: string) => {
    setBusy(true); setError(''); setNotice('');
    try { await work(); setNotice(message); await load(); }
    catch (caught) { setError((caught as Error).message); }
    finally { setBusy(false); }
  };
  const downloadCsv = (name: string, rows: Array<Record<string, unknown>>) => {
    if (!rows.length) return;
    const keys = Object.keys(rows[0]);
    const csv = [keys.join(','), ...rows.map((row) => keys.map((key) => `"${String(row[key] ?? '').replaceAll('"', '""')}"`).join(','))].join('\r\n');
    const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
    const link = document.createElement('a'); link.href = url; link.download = name; link.click(); URL.revokeObjectURL(url);
  };

  return <section className="operations-panel" aria-live="polite" aria-busy={loading}>
    <div className="operations-toolbar">
      <div><p className="eyebrow">CAREER360 OPERATIONS</p><h2>{kind === 'users' ? 'User accounts' : kind === 'payments' ? 'Payments ledger' : 'Reports & moderation'}</h2></div>
      <div className="toolbar-actions">
        {kind === 'users' && <input aria-label="Search users" placeholder="Search this page" value={search} onChange={(e) => setSearch(e.target.value)} />}
        {kind === 'payments' && available && <select aria-label="Filter payments" value={status} onChange={(e) => setStatus(e.target.value)}><option value="all">All statuses</option><option value="paid">Paid</option><option value="created">Awaiting payment</option><option value="failed">Failed</option><option value="refunded">Refunded</option></select>}
        {kind === 'payments' && available && <button className="text-button" onClick={() => downloadCsv('career360-payments.csv', payments as unknown as Array<Record<string, unknown>>)}>Export CSV</button>}
        {kind === 'reports' && available && <button className="text-button" onClick={() => downloadCsv('career360-reports.csv', reports as unknown as Array<Record<string, unknown>>)}>Export CSV</button>}
        <button className="text-button" disabled={loading || loadingMore} onClick={() => void load()}>{loading ? "Refreshing…" : "Refresh"}</button>
      </div>
    </div>
    {error && <div className="banner error" role="alert">{error}</div>}
    {notice && <div className="banner success" role="status">{notice}</div>}
    {loading && !hasLoaded ? (
      kind === 'reports' ? (
        <div className="content-list" aria-busy="true" aria-label="Loading records">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="content-row" style={{ pointerEvents: 'none' }}>
              <div style={{ flex: 1 }}>
                <span className="skeleton-bone" style={{ width: '70px', height: '18px', borderRadius: '4px', marginBottom: '10px' }} />
                <span className="skeleton-bone" style={{ width: `${55 - (i % 2) * 10}%`, height: '16px', marginBottom: '8px' }} />
                <span className="skeleton-bone" style={{ width: '75%', height: '13px' }} />
              </div>
              <div className="row-buttons">
                <span className="skeleton-bone" style={{ width: '60px', height: '32px', borderRadius: '6px' }} />
                <span className="skeleton-bone" style={{ width: '60px', height: '32px', borderRadius: '6px' }} />
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="operations-table-wrap" aria-busy="true" aria-label="Loading records">
          <table className="operations-table">
            <thead>
              <tr>
                {kind === 'users' ? (
                  <><th>Account</th><th>Role</th><th>Verification</th><th>Last sign in</th><th>Status / action</th></>
                ) : (
                  <><th>Order</th><th>Employer / plan</th><th>Amount</th><th>Tax</th><th>Status</th><th>Created / paid / refund</th><th>Action</th></>
                )}
              </tr>
            </thead>
            <tbody>
              {[1, 2, 3, 4, 5].map((i) => (
                <tr key={i} className="skeleton-table-row">
                  <td>
                    <span className="skeleton-bone" style={{ width: '60%', height: '14px', marginBottom: '6px' }} />
                    <span className="skeleton-bone" style={{ width: '45%', height: '11px' }} />
                  </td>
                  <td><span className="skeleton-bone" style={{ width: '70px', height: '14px' }} /></td>
                  <td><span className="skeleton-bone" style={{ width: '60px', height: '14px' }} /></td>
                  <td><span className="skeleton-bone" style={{ width: '85px', height: '14px' }} /></td>
                  <td><span className="skeleton-bone" style={{ width: '65px', height: '22px', borderRadius: '4px' }} /></td>
                  {kind === 'payments' && (
                    <>
                      <td><span className="skeleton-bone" style={{ width: '90px', height: '14px' }} /></td>
                      <td><span className="skeleton-bone" style={{ width: '80px', height: '28px', borderRadius: '6px' }} /></td>
                    </>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )
    ) : error && !users.length && !payments.length && !reports.length ? <div className="empty-state" role="alert"><h3>Records could not be loaded</h3><p>Use Refresh to try again.</p></div> : !available ? <div className="empty-state" role="status"><h3>{kind === 'payments' ? 'Billing records are unavailable' : 'Job reports are unavailable'}</h3><p>This section will reopen when its stored records are connected to the admin service.</p></div> : <>
      {kind === 'users' && <><div className="operations-table-wrap"><table className="operations-table"><thead><tr><th>Account</th><th>Role</th><th>Verification</th><th>Last sign in</th><th>Status / action</th></tr></thead><tbody>
        {users.map((user) => <tr key={user.uid}><td><strong>{user.displayName || 'Unnamed account'}</strong><small>{user.email || user.uid}</small></td><td>{user.role}</td><td>{user.emailVerified ? 'Verified' : 'Unverified'}</td><td>{date(user.lastSignInAt)}</td><td><span className={`status-pill ${user.disabled ? 'status-danger' : 'status-live'}`}>{user.disabled ? 'Suspended' : 'Active'}</span>{user.uid !== auth?.currentUser?.uid && <button className="row-action" disabled={busy} onClick={() => { const reason = user.disabled ? '' : window.prompt('Reason for suspending this account?'); if (user.disabled || reason) void act(async () => setUserDisabled(await token(), user.uid, !user.disabled, reason || ''), 'Account status updated.'); }}> {user.disabled ? 'Restore' : 'Suspend'}</button>}</td></tr>)}
        {!users.length && <tr><td colSpan={5}>No accounts found in this page.</td></tr>}
      </tbody></table></div>{nextPage && <button className="text-button" disabled={busy || loading || loadingMore} onClick={async () => { const currentRequest = requestId.current; setLoadingMore(true); try { const data = await listUsers(await token(), search, nextPage); if (currentRequest !== requestId.current) return; setUsers((current) => [...current, ...data.users]); setNextPage(data.nextPageToken); } catch (e) { if (currentRequest === requestId.current) setError((e as Error).message); } finally { setLoadingMore(false); } }}>{loadingMore ? "Loading more…" : "Load more accounts"}</button>}</>}
      {kind === 'payments' && <><div className="operations-table-wrap"><table className="operations-table"><thead><tr><th>Order</th><th>Employer / plan</th><th>Amount</th><th>Tax</th><th>Status</th><th>Created / paid / refund</th><th>Action</th></tr></thead><tbody>
        {payments.map((p) => <tr key={p.id}><td><strong>{p.id}</strong><small>{p.paymentId || 'No payment captured'}</small></td><td>{p.employerUid}<small>{p.planName} · {p.planId}</small></td><td>{money(p.amountPaise)}<small>{p.currency}</small></td><td>{money(p.taxPaise)}<small>{p.taxMode}, {p.taxRateBps / 100}% GST</small></td><td><span className={`status-pill ${p.status === 'paid' ? 'status-live' : p.status === 'refunded' ? 'status-danger' : ''}`}>{p.status}</span>{p.refundStatus && <small>Refund: {p.refundStatus}</small>}</td><td>{date(p.createdAt)}<small>Paid {date(p.paidAt)}</small>{p.refundRequestedAt && <small>Requested {date(p.refundRequestedAt)}</small>}</td><td>{p.status === 'paid' && (!p.refundStatus || p.refundStatus === 'failed') && <button className="row-action danger-action" disabled={busy} onClick={() => { const reason = window.prompt(`Reason for full refund of ${money(p.amountPaise)}?`); if (!reason) return; if (reason.trim().length < 5) { setError('Enter a refund reason with at least five characters.'); return; } if (window.confirm(`Send a full refund request for order ${p.id}? This action cannot be undone.`)) void act(async () => refundPayment(await token(), p.id, reason.trim()), 'Full refund requested. Razorpay will confirm processing.'); }}>{p.refundStatus === 'failed' ? 'Retry full refund' : 'Full refund'}</button>}{p.refundStatus && p.refundStatus !== 'processed' && p.refundStatus !== 'partial' && <button className="row-action" disabled={busy} onClick={() => void act(async () => reconcilePaymentRefund(await token(), p.id), 'Refund status refreshed.')}>Check refund</button>}{p.refundStatus && <small>{p.refundReason}</small>}</td></tr>)}
        {!payments.length && <tr><td colSpan={7}>No payment records match this filter.</td></tr>}
      </tbody></table></div>{nextPaymentCursor && <button className="text-button" onClick={async () => { try { const data = await listPayments(await token(), status, nextPaymentCursor); setPayments((current) => [...current, ...data.payments]); setNextPaymentCursor(data.nextCursor); } catch (e) { setError((e as Error).message); } }}>Load more payments</button>}</>}
      {kind === 'reports' && <><div className="report-metrics">{summary && Object.entries(summary).map(([key, value]) => <div className="stat-card" key={key}><span className="stat-label">{key.replace(/[A-Z]/g, (letter) => ` ${letter.toLowerCase()}`)}</span><strong className="stat-value">{value}</strong></div>)}</div><h3 className="section-title">Pending job reports <span>{reports.length}</span></h3><div className="content-list">{reports.map((report) => <ReportRow key={report.id} report={report} busy={busy} act={act} />)}{!reports.length && <div className="empty-state"><h3>No pending job reports</h3><p>Reports submitted by job seekers will appear here for review.</p></div>}</div>{nextReportCursor && <button className="text-button" disabled={busy} onClick={async () => { try { const data = await getReports(await token(), nextReportCursor); setReports((current) => [...current, ...data.reports]); setNextReportCursor(data.nextCursor); } catch (e) { setError((e as Error).message); } }}>Load more reports</button>}</>}
    </>}
  </section>;
}

function ReportRow({ report, busy, act }: { report: JobReport; busy: boolean; act: (work: () => Promise<unknown>, message: string) => Promise<void> }) {
  const token = async () => { if (!auth?.currentUser) throw new Error('Sign in again to continue.'); return auth.currentUser.getIdToken(); };
  return <article className="content-row"><div><span className="status-pill">{report.reason}</span><h3>{report.jobTitle || 'Job listing'} · {report.companyName}</h3><p>{report.details || 'No extra details provided.'}</p><small>Job ID {report.jobId} · Reported {date(report.createdAt)}</small></div><div className="row-buttons"><button className="row-action" disabled={busy} onClick={() => { if (window.confirm('Dismiss this report?')) void act(async () => resolveReport(await token(), report.id, 'dismissed'), 'Report dismissed.'); }}>Dismiss</button><button className="row-action danger-action" disabled={busy} onClick={() => { if (window.confirm('Close the reported job and resolve this report?')) void act(async () => resolveReport(await token(), report.id, 'job_closed'), 'Job closed and report resolved.'); }}>Close job</button></div></article>;
}
