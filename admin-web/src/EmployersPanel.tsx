import { useCallback, useEffect, useRef, useState } from 'react';
import { adjustEmployerQuota, getEmployer, listEmployers, reviewEmployer, type EmployerDetails, type EmployerRecord } from './api';
import { auth } from './supabase';

type Filter = 'pending' | 'approved' | 'rejected' | 'all';
const date = (value: string | null | undefined) => {
  if (!value) return 'Not available';
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? 'Not available' : parsed.toLocaleString();
};
const value = (entry: string | number | null | undefined) =>
  entry === null || entry === undefined || entry === '' ? 'Not provided' : String(entry);

function DetailField({ label, entry }: { label: string; entry: string | number | null | undefined }) {
  return <div className="job-seeker-detail-field"><span>{label}</span><strong>{value(entry)}</strong></div>;
}

function Status({ status }: { status: EmployerRecord['status'] }) {
  return <span className={`status-pill pill-${status === 'suspended' ? 'rejected' : status}`}>
    {status === 'approved' ? 'Approved' : status === 'pending' ? 'Pending review' : status === 'rejected' ? 'Rejected' : 'Suspended'}
  </span>;
}

export default function EmployersPanel() {
  const [employers, setEmployers] = useState<EmployerRecord[]>([]);
  const [statusFilter, setStatusFilter] = useState<Filter>('pending');
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const requestId = useRef(0);
  const [busyUid, setBusyUid] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [reasonUid, setReasonUid] = useState<string | null>(null);
  const [reason, setReason] = useState('');
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [selectedUid, setSelectedUid] = useState<string | null>(null);
  const [details, setDetails] = useState<EmployerDetails | null>(null);
  const [detailsLoading, setDetailsLoading] = useState(false);
  const [detailsError, setDetailsError] = useState('');
  const [detailsRefresh, setDetailsRefresh] = useState(0);
  const [quotaChange, setQuotaChange] = useState('');
  const [quotaReason, setQuotaReason] = useState('');

  const token = async () => {
    if (!auth?.currentUser) throw new Error('Sign in again to continue.');
    return auth.currentUser.getIdToken();
  };

  const load = useCallback(async (background = false) => {
    const currentRequest = ++requestId.current;
    if (background) setRefreshing(true);
    else { setLoading(true); setRefreshing(false); }
    try {
      const result = await listEmployers(await token(), statusFilter, search);
      if (currentRequest !== requestId.current) return;
      setEmployers(result.employers);
      setNextCursor(result.nextCursor);
      setError('');
    } catch (caught) {
      if (currentRequest === requestId.current) setError((caught as Error).message);
    } finally {
      if (currentRequest === requestId.current) { setLoading(false); setRefreshing(false); }
    }
  }, [statusFilter, search]);

  useEffect(() => {
    const timer = setTimeout(() => { void load(); }, search ? 250 : 0);
    return () => { clearTimeout(timer); ++requestId.current; };
  }, [load, search]);

  useEffect(() => {
    if (!selectedUid) { setDetails(null); setDetailsError(''); return; }
    let active = true;
    setDetailsLoading(true);
    setDetailsError('');
    void token().then((idToken) => getEmployer(idToken, selectedUid))
      .then((result) => { if (active) setDetails(result.employer); })
      .catch((caught) => { if (active) setDetailsError((caught as Error).message); })
      .finally(() => { if (active) setDetailsLoading(false); });
    return () => { active = false; };
  }, [selectedUid, detailsRefresh]);

  const openDetails = (uid: string) => {
    setDetails(null);
    setNotice('');
    setError('');
    setSelectedUid(uid);
  };

  const moderate = async (employer: EmployerRecord, decision: 'approved' | 'rejected') => {
    setBusyUid(employer.uid);
    setError('');
    setDetailsError('');
    setNotice('');
    try {
      await reviewEmployer(await token(), employer.uid, decision, decision === 'rejected' ? reason.trim() : undefined);
      setNotice(decision === 'approved'
        ? employer.status === 'pending' ? 'Company approved.' : 'Company reactivated.'
        : employer.status === 'pending' ? 'Application rejected.' : 'Company suspended.');
      setReasonUid(null);
      setReason('');
      if (selectedUid === employer.uid) setDetailsRefresh((current) => current + 1);
      await load(true);
    } catch (caught) {
      const message = (caught as Error).message;
      if (selectedUid === employer.uid) setDetailsError(message);
      else setError(message);
    } finally {
      setBusyUid(null);
    }
  };

  const actions = (employer: EmployerRecord) => {
    const isBusy = busyUid === employer.uid;
    if (reasonUid === employer.uid) {
      return <div className="employer-reason-form">
        <label htmlFor={`employer-reason-${employer.uid}`}>{employer.status === 'pending' ? 'Rejection reason' : 'Suspension reason'}</label>
        <input id={`employer-reason-${employer.uid}`} value={reason} maxLength={500}
          onChange={(event) => setReason(event.target.value)}
          placeholder="Enter a reason (at least 3 characters)" autoFocus />
        <div className="employer-action-buttons">
          <button className="row-action danger-action" disabled={isBusy || reason.trim().length < 3}
            onClick={() => void moderate(employer, 'rejected')}>{isBusy ? 'Saving…' : 'Confirm'}</button>
          <button className="row-action" disabled={isBusy} onClick={() => { setReasonUid(null); setReason(''); }}>Cancel</button>
        </div>
      </div>;
    }
    return <div className="employer-action-buttons">
      {employer.status !== 'approved' &&
        <button className="row-action" disabled={isBusy} onClick={() => void moderate(employer, 'approved')}>
          {isBusy ? 'Saving…' : employer.status === 'pending' ? 'Approve' : 'Reactivate'}
        </button>}
      {(employer.status === 'pending' || employer.status === 'approved') &&
        <button className="row-action danger-action" disabled={isBusy}
          onClick={() => { setReasonUid(employer.uid); setReason(''); }}>
          {employer.status === 'pending' ? 'Reject' : 'Suspend'}
        </button>}
    </div>;
  };

  if (selectedUid) {
    return <section className="job-seeker-detail-page employer-detail-page" aria-busy={detailsLoading}>
      <div className="job-seeker-detail-toolbar">
        <button className="text-button" onClick={() => { setSelectedUid(null); setReasonUid(null); setReason(''); }}>← Back to employers</button>
        <button className="text-button" disabled={detailsLoading} onClick={() => setDetailsRefresh((current) => current + 1)}>
          {detailsLoading ? 'Refreshing…' : 'Refresh details'}
        </button>
      </div>
      {detailsError && <div className="banner error" role="alert">{detailsError}</div>}
      {notice && <div className="banner success" role="status">{notice}</div>}
      {detailsLoading && !details && <div className="panel-loading">Loading company profile…</div>}
      {!detailsLoading && !details && <button className="secondary-button" onClick={() => setDetailsRefresh((current) => current + 1)}>Try again</button>}
      {details && <>
        <header className="job-seeker-profile-header">
          <div className="job-seeker-avatar employer-avatar" aria-hidden="true">{(details.companyName || 'C').charAt(0).toUpperCase()}
            {details.logoUrl && <img src={details.logoUrl} alt="" onError={(event) => { event.currentTarget.style.display = 'none'; }} />}
          </div>
          <div className="job-seeker-profile-title">
            <p className="section-eyebrow">EMPLOYER PROFILE</p>
            <h2>{details.companyName || 'Unnamed company'}</h2>
            <p>{[details.industry, details.district, details.state].filter(Boolean).join(' · ') || details.email}</p>
          </div>
          <div className="job-seeker-profile-actions"><Status status={details.status} /></div>
        </header>
        <div className="employer-detail-review job-seeker-detail-section">
          <div><h3>Account review</h3>
            <p>{details.status === 'pending' ? 'Review this company before it can use the employer portal.' :
              details.status === 'approved' ? 'This company can use the employer portal.' :
              details.status === 'suspended' ? 'This company cannot use the employer portal.' : 'This application was rejected.'}</p>
            {details.rejectionReason && <p className="employer-review-reason"><strong>Reason:</strong> {details.rejectionReason}</p>}
          </div>
          {actions(details)}
        </div>
        <div className="job-seeker-account-meta">
          <DetailField label="Email verification" entry={details.emailVerified ? 'Verified' : 'Unverified'} />
          <DetailField label="Account created" entry={date(details.createdAt)} />
          <DetailField label="Last sign in" entry={date(details.lastSignInAt)} />
          <DetailField label="Reviewed" entry={date(details.reviewedAt)} />
        </div>
        <div className="job-seeker-detail-grid">
          <section className="job-seeker-detail-section"><h3>Subscriptions and quota</h3>
            {details.subscriptions.length === 0 ? <p>No subscription purchases recorded.</p> :
              details.subscriptions.map((subscription) => <div className="employer-subscription-row" key={subscription.id}>
                <strong>{subscription.plan_name} · {subscription.status}</strong>
                <span>{subscription.used_posts} of {subscription.total_posts} posts used</span>
                <small>{date(subscription.starts_at)} to {date(subscription.expires_at)}</small>
              </div>)}
            {details.subscriptions.some((subscription) => subscription.status === 'active' && new Date(subscription.expires_at) > new Date()) &&
              <form className="employer-quota-form" onSubmit={async (event) => {
                event.preventDefault();
                const delta = Number(quotaChange);
                if (!Number.isInteger(delta) || delta === 0 || quotaReason.trim().length < 5) return;
                setBusyUid(details.uid); setDetailsError(''); setNotice('');
                try {
                  await adjustEmployerQuota(await token(), details.uid, delta, quotaReason.trim());
                  setQuotaChange(''); setQuotaReason(''); setNotice('Quota updated and logged.');
                  setDetailsRefresh((current) => current + 1);
                  await load(true);
                } catch (caught) { setDetailsError((caught as Error).message); }
                finally { setBusyUid(null); }
              }}>
                <label>Adjust total posts (+ or −)<input type="number" step="1" required value={quotaChange}
                  onChange={(event) => setQuotaChange(event.target.value)} /></label>
                <label>Reason<input required minLength={5} maxLength={500} value={quotaReason}
                  onChange={(event) => setQuotaReason(event.target.value)} /></label>
                <button className="row-action" disabled={busyUid === details.uid}>Save quota change</button>
              </form>}
          </section>
          <section className="job-seeker-detail-section"><h3>Payment history</h3>
            {details.orders.length === 0 ? <p>No payment orders yet.</p> :
              details.orders.map((order) => <div className="employer-subscription-row" key={order.id}>
                <strong>{order.plan_name} · ₹{(order.amount_paise / 100).toLocaleString('en-IN')}</strong>
                <span>{order.status} · GST ₹{(order.tax_paise / 100).toFixed(2)}</span>
                <small>{date(order.paid_at || order.created_at)} · {order.id}</small>
              </div>)}
          </section>
          <section className="job-seeker-detail-section"><h3>Recruiter and contact</h3><div className="job-seeker-fields">
            <DetailField label="Recruiter name" entry={details.contactName} />
            <DetailField label="Designation" entry={details.designation} />
            <DetailField label="Account email" entry={details.email} />
            <DetailField label="Mobile number" entry={details.phone} />
            <DetailField label="WhatsApp number" entry={details.whatsappPhone} />
            <DetailField label="WhatsApp contact" entry={details.whatsappSameAsPhone ? 'Same as mobile' : 'Separate number'} />
          </div></section>
          <section className="job-seeker-detail-section"><h3>Company information</h3><div className="job-seeker-fields">
            <DetailField label="Company name" entry={details.companyName} />
            <DetailField label="Industry" entry={details.industry} />
            <DetailField label="Company size" entry={details.companySize} />
            <DetailField label="Registration / GSTIN" entry={details.registrationNumber} />
            <DetailField label="Website" entry={details.website} />
            <DetailField label="About the company" entry={details.description} />
          </div></section>
          <section className="job-seeker-detail-section"><h3>Location and address</h3><div className="job-seeker-fields">
            <DetailField label="Street address" entry={details.address} />
            <DetailField label="City" entry={details.city} />
            <DetailField label="District" entry={details.district} />
            <DetailField label="State" entry={details.state} />
            <DetailField label="Postal code" entry={details.postalCode} />
          </div></section>
          <section className="job-seeker-detail-section"><h3>Hiring account</h3><div className="job-seeker-fields">
            <DetailField label="Account access" entry={details.accountStatus} />
            <DetailField label="Posting credits" entry={details.postingCredits} />
            <DetailField label="Plan" entry={details.activePlanName || details.activePlan} />
            <DetailField label="Plan tier" entry={details.planTier} />
            <DetailField label="Plan reach" entry={details.planReach} />
            <DetailField label="Listing duration" entry={details.listingDays ? `${details.listingDays} days` : ''} />
            <DetailField label="Credits expire" entry={date(details.creditsExpireAt)} />
            <DetailField label="Last profile update" entry={date(details.updatedAt)} />
          </div></section>
        </div>
      </>}
    </section>;
  }

  return <div className="employers-panel">
    {notice && <div className="banner success" role="status">{notice}</div>}
    {error && <div className="banner error" role="alert">{error}</div>}
    <div className="panel-controls">
      <div className="filter-tabs" aria-label="Filter companies">
        {(['pending', 'approved', 'rejected', 'all'] as const).map((filter) =>
          <button key={filter} type="button" className={`filter-tab ${statusFilter === filter ? 'active' : ''}`}
            aria-pressed={statusFilter === filter} onClick={() => setStatusFilter(filter)}>
            {filter === 'pending' ? 'Needs review' : filter === 'approved' ? 'Approved' : filter === 'rejected' ? 'Rejected / suspended' : 'All companies'}
          </button>)}
      </div>
      <div className="search-box">
        <input aria-label="Search companies" type="search" placeholder="Search company, contact or district"
          value={search} onChange={(event) => setSearch(event.target.value)} />
      </div>
      <button type="button" className="text-button panel-refresh" disabled={loading || loadingMore || refreshing}
        onClick={() => void load(true)}>{refreshing ? 'Refreshing…' : 'Refresh'}</button>
    </div>
    {loading && <div className="panel-loading" aria-busy="true">Loading companies…</div>}
    {!loading && employers.length === 0 && <div className="empty-panel">
      <p>{error ? 'Companies could not be loaded. Use Refresh to try again.' : 'No companies found in this section.'}</p>
    </div>}
    {!loading && employers.length > 0 && <div className="operations-table-wrap">
      <table className="operations-table employers-table">
        <thead><tr><th>Company</th><th>Recruiter</th><th>Location</th><th>Submitted</th><th>Status</th><th>Details</th><th>Action</th></tr></thead>
        <tbody>{employers.map((employer) => <tr key={employer.uid}>
          <td data-label="Company"><strong>{employer.companyName || 'Unnamed company'}</strong><small>{employer.industry || employer.email || 'Industry not provided'}</small></td>
          <td data-label="Recruiter"><strong>{employer.contactName || 'Not provided'}</strong><small>{employer.designation || employer.email || ''}</small></td>
          <td data-label="Location">{[employer.district, employer.state].filter(Boolean).join(', ') || 'Not provided'}</td>
          <td data-label="Submitted">{date(employer.createdAt)}</td>
          <td data-label="Status"><Status status={employer.status} /></td>
          <td data-label="Details"><button className="row-action employer-view-button" onClick={() => openDetails(employer.uid)}>View profile</button></td>
          <td data-label="Action">{actions(employer)}</td>
        </tr>)}</tbody>
      </table>
    </div>}
    {!loading && nextCursor && <div className="pagination-row">
      <button className="text-button" disabled={loadingMore} onClick={async () => {
        if (!nextCursor) return;
        const currentRequest = requestId.current;
        setLoadingMore(true);
        try {
          const result = await listEmployers(await token(), statusFilter, search, nextCursor);
          if (currentRequest !== requestId.current) return;
          setEmployers((current) => [...current, ...result.employers]);
          setNextCursor(result.nextCursor);
        } catch (caught) {
          if (currentRequest === requestId.current) setError((caught as Error).message);
        } finally { setLoadingMore(false); }
      }}>{loadingMore ? 'Loading more…' : 'Load more companies'}</button>
    </div>}
  </div>;
}
