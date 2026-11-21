import { useCallback, useEffect, useRef, useState } from 'react';
import { auth } from './supabase';
import { ApiError, getJobSeeker, listPayments, listJobSeekers,
  reconcilePaymentRefund, refundPayment, setUserDisabled, type JobSeekerDetails, type JobSeekerRecord, type PaymentRecord } from './api';

type Props = { kind: 'jobseekers' | 'payments' };
const money = (paise: number) => new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR' }).format(paise / 100);
const date = (value: string | null | undefined) => value ? new Date(value).toLocaleString() : '—';

export default function OperationsPanels({ kind }: Props) {
  const [jobSeekers, setJobSeekers] = useState<JobSeekerRecord[]>([]);
  const [selectedJobSeekerUid, setSelectedJobSeekerUid] = useState<string | null>(null);
  const [jobSeekerDetails, setJobSeekerDetails] = useState<JobSeekerDetails | null>(null);
  const [detailsLoading, setDetailsLoading] = useState(false);
  const [detailsError, setDetailsError] = useState('');
  const [detailsRefresh, setDetailsRefresh] = useState(0);
  const [payments, setPayments] = useState<PaymentRecord[]>([]);
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('all');
  const [nextPage, setNextPage] = useState<string | null>(null);
  const [nextPaymentCursor, setNextPaymentCursor] = useState<string | null>(null);
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
      if (kind === 'jobseekers') { const data = await listJobSeekers(idToken, search); if (currentRequest !== requestId.current) return; setJobSeekers(data.jobSeekers); setNextPage(data.nextPageToken); setAvailable(true); }
      if (kind === 'payments') { const data = await listPayments(idToken, status); if (currentRequest !== requestId.current) return; setPayments(data.payments); setNextPaymentCursor(data.nextCursor); setAvailable(data.available !== false); }
    } catch (caught) {
      if (currentRequest === requestId.current) setError(caught instanceof ApiError ? caught.message : (caught as Error).message);
    } finally { if (currentRequest === requestId.current) { setLoading(false); setHasLoaded(true); } }
  }, [kind, search, status]);

  useEffect(() => {
    if (kind !== 'jobseekers' || !selectedJobSeekerUid) {
      setJobSeekerDetails(null);
      setDetailsError('');
      return;
    }
    let active = true;
    setDetailsLoading(true);
    setDetailsError('');
    void token().then((idToken) => getJobSeeker(idToken, selectedJobSeekerUid))
      .then((result) => { if (active) setJobSeekerDetails(result.jobSeeker); })
      .catch((caught) => { if (active) setDetailsError(caught instanceof Error ? caught.message : 'Could not load this job seeker.'); })
      .finally(() => { if (active) setDetailsLoading(false); });
    return () => { active = false; };
  }, [kind, selectedJobSeekerUid, detailsRefresh]);
  useEffect(() => {
    const timer = setTimeout(() => { void load(); }, kind === 'jobseekers' && search ? 250 : 0);
    return () => { clearTimeout(timer); ++requestId.current; };
  }, [load, kind, search]);
  const act = async (work: () => Promise<unknown>, message: string) => {
    setBusy(true); setError(''); setNotice('');
    try { await work(); setNotice(message); await load(); }
    catch (caught) {
      const message = (caught as Error).message;
      if (kind === 'jobseekers') await load();
      setError(message);
    }
    finally { setBusy(false); }
  };
  const downloadCsv = (name: string, rows: Array<Record<string, unknown>>) => {
    if (!rows.length) return;
    const keys = Object.keys(rows[0]);
    const csv = [keys.join(','), ...rows.map((row) => keys.map((key) => `"${String(row[key] ?? '').replaceAll('"', '""')}"`).join(','))].join('\r\n');
    const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
    const link = document.createElement('a'); link.href = url; link.download = name; link.click(); URL.revokeObjectURL(url);
  };

  if (kind === 'jobseekers' && selectedJobSeekerUid) {
    return <JobSeekerDetailView
      jobSeeker={jobSeekerDetails}
      loading={detailsLoading}
      error={detailsError || error}
      busy={busy}
      notice={notice}
      onBack={() => { setSelectedJobSeekerUid(null); setDetailsError(''); }}
      onRefresh={() => setDetailsRefresh((current) => current + 1)}
      onToggleStatus={(user) => {
        const reason = user.disabled ? '' : window.prompt('Reason for suspending this job seeker?');
        if (!user.disabled && !reason) return;
        void act(async () => {
          await setUserDisabled(await token(), user.uid, !user.disabled, reason || '');
          setJobSeekerDetails((current) => current ? { ...current, disabled: !current.disabled } : current);
        }, 'Job seeker status updated.');
      }}
    />;
  }

  return <section className="operations-panel" aria-live="polite" aria-busy={loading}>
    <div className="operations-toolbar">
      <div><p className="eyebrow">CAREER360 OPERATIONS</p><h2>{kind === 'jobseekers' ? 'Job seeker accounts' : 'Payments ledger'}</h2></div>
      <div className="toolbar-actions">
        {kind === 'jobseekers' && <input aria-label="Search job seekers" placeholder="Search job seekers" value={search} onChange={(e) => setSearch(e.target.value)} />}
        {kind === 'payments' && available && <select aria-label="Filter payments" value={status} onChange={(e) => setStatus(e.target.value)}><option value="all">All statuses</option><option value="paid">Paid</option><option value="created">Awaiting payment</option><option value="failed">Failed</option><option value="refunded">Refunded</option></select>}
        {kind === 'payments' && available && <button className="text-button" onClick={() => downloadCsv('career360-payments.csv', payments as unknown as Array<Record<string, unknown>>)}>Export CSV</button>}
        <button className="text-button" disabled={loading || loadingMore} onClick={() => void load()}>{loading ? "Refreshing…" : "Refresh"}</button>
      </div>
    </div>
    {error && <div className="banner error" role="alert">{error}</div>}
    {notice && <div className="banner success" role="status">{notice}</div>}
    {loading && !hasLoaded ? (
        <div className="operations-table-wrap" aria-busy="true" aria-label="Loading records">
          <table className={`operations-table ${kind === 'jobseekers' ? 'job-seekers-table' : ''}`}>
            <thead>
              <tr>
                {kind === 'jobseekers' ? (
                  <><th>Job seeker</th><th>Email verification</th><th>Last sign in</th><th>Details</th><th>Status / action</th></>
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
                  {kind === 'payments' && <td><span className="skeleton-bone" style={{ width: '70px', height: '14px' }} /></td>}
                  <td><span className="skeleton-bone" style={{ width: '60px', height: '14px' }} /></td>
                  <td><span className="skeleton-bone" style={{ width: '85px', height: '14px' }} /></td>
                  {kind === 'jobseekers' && <td><span className="skeleton-bone" style={{ width: '80px', height: '28px', borderRadius: '6px' }} /></td>}
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
    ) : error && !jobSeekers.length && !payments.length ? <div className="empty-state" role="alert"><h3>Records could not be loaded</h3><p>Use Refresh to try again.</p></div> : !available ? <div className="empty-state" role="status"><h3>Billing records are unavailable</h3><p>This section will reopen when its stored records are connected to the admin service.</p></div> : <>
      {kind === 'jobseekers' && <><div className="operations-table-wrap"><table className="operations-table job-seekers-table"><thead><tr><th>Job seeker</th><th>Email verification</th><th>Last sign in</th><th>Details</th><th>Status / action</th></tr></thead><tbody>
        {jobSeekers.map((user) => <tr key={user.uid}><td><strong>{user.displayName || 'Unnamed job seeker'}</strong><small>{user.email || user.uid}</small></td><td>{user.emailVerified ? 'Verified' : 'Unverified'}</td><td>{date(user.lastSignInAt)}</td><td><button className="row-action" onClick={() => { setNotice(''); setSelectedJobSeekerUid(user.uid); }}>View profile</button></td><td><div className="job-seeker-actions-cell"><span className={`status-pill ${user.disabled ? 'status-danger' : 'status-live'}`}>{user.disabled ? 'Suspended' : 'Active'}</span>{user.uid !== auth?.currentUser?.uid && <button className="row-action" disabled={busy} onClick={() => { const reason = user.disabled ? '' : window.prompt('Reason for suspending this job seeker?'); if (user.disabled || reason) void act(async () => setUserDisabled(await token(), user.uid, !user.disabled, reason || ''), 'Job seeker status updated.'); }}>{user.disabled ? 'Restore' : 'Suspend'}</button>}</div></td></tr>)}
        {!jobSeekers.length && <tr><td colSpan={5}>{nextPage ? 'No job seekers found in this group.' : 'No job seeker accounts found.'}</td></tr>}
      </tbody></table></div>{nextPage && <button className="text-button" disabled={busy || loading || loadingMore} onClick={async () => { const currentRequest = requestId.current; setLoadingMore(true); try { const data = await listJobSeekers(await token(), search, nextPage); if (currentRequest !== requestId.current) return; setJobSeekers((current) => [...current, ...data.jobSeekers]); setNextPage(data.nextPageToken); } catch (e) { if (currentRequest === requestId.current) setError((e as Error).message); } finally { setLoadingMore(false); } }}>{loadingMore ? "Loading more…" : "Load more job seekers"}</button>}</>}
      {kind === 'payments' && <><div className="operations-table-wrap"><table className="operations-table"><thead><tr><th>Order</th><th>Employer / plan</th><th>Amount</th><th>Tax</th><th>Status</th><th>Created / paid / refund</th><th>Action</th></tr></thead><tbody>
        {payments.map((p) => <tr key={p.id}><td><strong>{p.id}</strong><small>{p.paymentId || 'No payment captured'}</small></td><td>{p.employerUid}<small>{p.planName} · {p.planId}</small></td><td>{money(p.amountPaise)}<small>{p.currency}</small></td><td>{money(p.taxPaise)}<small>{p.taxMode}, {p.taxRateBps / 100}% GST</small></td><td><span className={`status-pill ${p.status === 'paid' ? 'status-live' : p.status === 'refunded' ? 'status-danger' : ''}`}>{p.status}</span>{p.refundStatus && <small>Refund: {p.refundStatus}</small>}</td><td>{date(p.createdAt)}<small>Paid {date(p.paidAt)}</small>{p.refundRequestedAt && <small>Requested {date(p.refundRequestedAt)}</small>}</td><td>{p.status === 'paid' && (!p.refundStatus || p.refundStatus === 'failed') && <button className="row-action danger-action" disabled={busy} onClick={() => { const reason = window.prompt(`Reason for full refund of ${money(p.amountPaise)}?`); if (!reason) return; if (reason.trim().length < 5) { setError('Enter a refund reason with at least five characters.'); return; } if (window.confirm(`Send a full refund request for order ${p.id}? This action cannot be undone.`)) void act(async () => refundPayment(await token(), p.id, reason.trim()), 'Full refund requested. Razorpay will confirm processing.'); }}>{p.refundStatus === 'failed' ? 'Retry full refund' : 'Full refund'}</button>}{p.refundStatus && p.refundStatus !== 'processed' && p.refundStatus !== 'partial' && <button className="row-action" disabled={busy} onClick={() => void act(async () => reconcilePaymentRefund(await token(), p.id), 'Refund status refreshed.')}>Check refund</button>}{p.refundStatus && <small>{p.refundReason}</small>}</td></tr>)}
        {!payments.length && <tr><td colSpan={7}>No payment records match this filter.</td></tr>}
      </tbody></table></div>{nextPaymentCursor && <button className="text-button" onClick={async () => { try { const data = await listPayments(await token(), status, nextPaymentCursor); setPayments((current) => [...current, ...data.payments]); setNextPaymentCursor(data.nextCursor); } catch (e) { setError((e as Error).message); } }}>Load more payments</button>}</>}
    </>}
  </section>;
}
function displayValue(value: unknown): string {
  if (value === null || value === undefined || value === '') return 'Not provided';
  if (typeof value === 'boolean') return value ? 'Yes' : 'No';
  if (Array.isArray(value)) return value.length ? value.map(String).join(', ') : 'Not provided';
  return String(value);
}

function DetailField({ label, value }: { label: string; value: unknown }) {
  return <div className="job-seeker-detail-field"><span>{label}</span><strong>{displayValue(value)}</strong></div>;
}

function JobSeekerDetailView({ jobSeeker, loading, error, busy, notice, onBack, onRefresh, onToggleStatus }: {
  jobSeeker: JobSeekerDetails | null;
  loading: boolean;
  error: string;
  busy: boolean;
  notice: string;
  onBack: () => void;
  onRefresh: () => void;
  onToggleStatus: (jobSeeker: JobSeekerDetails) => void;
}) {
  if (loading && !jobSeeker) return <section className="job-seeker-detail-page" aria-busy="true"><button className="text-button" onClick={onBack}>← Back to job seekers</button><div className="panel-loading">Loading job seeker details…</div></section>;
  if (error && !jobSeeker) return <section className="job-seeker-detail-page"><button className="text-button" onClick={onBack}>← Back to job seekers</button><div className="banner error" role="alert">{error}</div><button className="secondary-button" onClick={onRefresh}>Try again</button></section>;
  if (!jobSeeker) return <section className="job-seeker-detail-page"><button className="text-button" onClick={onBack}>← Back to job seekers</button><div className="empty-state"><h3>Job seeker not found</h3><p>This account may have been removed or changed roles.</p></div></section>;

  const profile = jobSeeker.profile;
  const personal = profile.personalDetails || {};
  const education = profile.education || {};
  const experience = profile.experience || {};
  const name = profile.fullName || 'Unnamed job seeker';
  const birth = [personal.birthMonth, personal.birthYear].filter(Boolean).join(' ');

  return <section className="job-seeker-detail-page" aria-busy={loading}>
    <div className="job-seeker-detail-toolbar">
      <button className="text-button" onClick={onBack}>← Back to job seekers</button>
      <button className="text-button" disabled={loading} onClick={onRefresh}>{loading ? 'Refreshing…' : 'Refresh details'}</button>
    </div>
    {error && <div className="banner error" role="alert">{error}</div>}
    {notice && <div className="banner success" role="status">{notice}</div>}
    <header className="job-seeker-profile-header">
      <div className="job-seeker-avatar" aria-hidden="true">{name.charAt(0).toUpperCase()}
        {profile.profilePhotoUrl && <img src={profile.profilePhotoUrl} alt="" onError={(event) => { event.currentTarget.style.display = 'none'; }} />}
      </div>
      <div className="job-seeker-profile-title"><p className="section-eyebrow">JOB SEEKER PROFILE</p><h2>{name}</h2><p>{jobSeeker.email || 'No email address'}</p></div>
      <div className="job-seeker-profile-actions"><span className={`status-pill ${jobSeeker.disabled ? 'status-danger' : 'status-live'}`}>{jobSeeker.disabled ? 'Suspended' : 'Active'}</span><button className={`row-action ${jobSeeker.disabled ? '' : 'danger-action'}`} disabled={busy} onClick={() => onToggleStatus(jobSeeker)}>{busy ? 'Saving…' : jobSeeker.disabled ? 'Restore account' : 'Suspend account'}</button></div>
    </header>
    <div className="job-seeker-account-meta">
      <DetailField label="Email verification" value={jobSeeker.emailVerified ? 'Verified' : 'Unverified'} />
      <DetailField label="Mobile number" value={jobSeeker.phone} />
      <DetailField label="Account created" value={date(jobSeeker.createdAt)} />
      <DetailField label="Last sign in" value={date(jobSeeker.lastSignInAt)} />
    </div>
    {!profile.onboardingCompletedAt && <div className="job-seeker-incomplete-note">Profile setup is incomplete. Showing the information saved so far.</div>}
    <div className="job-seeker-detail-grid">
      <section className="job-seeker-detail-section"><h3>Personal information</h3><div className="job-seeker-fields">
        <DetailField label="Gender" value={personal.gender} />
        <DetailField label="Marital status" value={personal.maritalStatus} />
        <DetailField label="Birth month and year" value={birth} />
        <DetailField label="State" value={personal.state} />
        <DetailField label="District" value={profile.district} />
      </div></section>
      <section className="job-seeker-detail-section"><h3>Education</h3><div className="job-seeker-fields">
        <DetailField label="Education level" value={education.educationLevel} />
        <DetailField label="Qualification" value={education.qualification} />
        <DetailField label="College or school" value={education.collegeOrSchool} />
        <DetailField label="Year of passing" value={education.graduationYear} />
      </div></section>
      <section className="job-seeker-detail-section"><h3>Preferred roles</h3><div className="job-seeker-fields"><DetailField label="Job titles" value={profile.preferredJobTitles} /></div></section>
      <section className="job-seeker-detail-section"><h3>Experience</h3><div className="job-seeker-fields">
        <DetailField label="Work experience" value={experience.hasExperience === false ? 'Fresher' : experience.hasExperience === true ? 'Experienced' : undefined} />
        {experience.hasExperience === true && <>
          <DetailField label="Experience" value={[experience.experienceYears ? `${experience.experienceYears} years` : '', experience.experienceMonths ? `${experience.experienceMonths} months` : ''].filter(Boolean).join(' ')} />
          <DetailField label="Last company" value={experience.lastCompany} />
          <DetailField label="Last job title" value={experience.lastJobTitle} />
          <DetailField label="Salary expectation" value={experience.salary} />
          <DetailField label="Notice period" value={experience.noticePeriod} />
        </>}
      </div></section>
    </div>
  </section>;
}
