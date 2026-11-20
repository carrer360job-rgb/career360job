import { useEffect, useState, useCallback, useRef } from 'react';
import { listJobs, getJob, closeJob, reviewJob, type JobRecord, type JobDetails } from './api';
import { auth } from './supabase';

const date = (value: string | null) => value ? new Date(value).toLocaleString() : 'Not available';
const value = (entry: string | number | null | undefined) => entry === null || entry === undefined || entry === '' ? 'Not provided' : String(entry);
function DetailField({ label, entry }: { label: string; entry: string | number | null | undefined }) {
  return <div className="job-seeker-detail-field"><span>{label}</span><strong>{value(entry)}</strong></div>;
}
const statusLabel = (status: string) => status === 'active' ? 'Live' : status === 'pending' ? 'Needs review' : status === 'rejected' ? 'Rejected' : 'Closed';

export default function JobsPanel() {
  const [jobs, setJobs] = useState<JobRecord[]>([]);
  const [statusFilter, setStatusFilter] = useState<'pending' | 'active' | 'closed' | 'rejected' | 'all'>('pending');
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const requestId = useRef(0);
  const [busyJobId, setBusyJobId] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [selectedJobId, setSelectedJobId] = useState<string | null>(null);
  const [details, setDetails] = useState<JobDetails | null>(null);
  const [detailsLoading, setDetailsLoading] = useState(false);
  const [detailsError, setDetailsError] = useState('');
  const [detailsRefresh, setDetailsRefresh] = useState(0);

  useEffect(() => {
    if (!selectedJobId) { setDetails(null); setDetailsError(''); return; }
    let active = true;
    setDetails(null); setDetailsLoading(true); setDetailsError('');
    void (async () => {
      if (!auth?.currentUser) throw new Error('Sign in again to continue.');
      return getJob(await auth.currentUser.getIdToken(), selectedJobId);
    })().then(({ job }) => { if (active) setDetails(job); })
      .catch((error) => { if (active) setDetailsError((error as Error).message); })
      .finally(() => { if (active) setDetailsLoading(false); });
    return () => { active = false; };
  }, [selectedJobId, detailsRefresh]);

  const load = useCallback(async (background = false) => {
    const currentRequest = ++requestId.current;
    try {
      if (background) setRefreshing(true); else { setRefreshing(false); setLoading(true); }
      const token = await auth.currentUser.getIdToken();
      const res = await listJobs(token, statusFilter, search);
      if (currentRequest !== requestId.current) return;
      setJobs(res.jobs);
      setNextCursor(res.nextCursor);
      setError('');
    } catch (err) {
      if (currentRequest === requestId.current) setError((err as Error).message);
    } finally {
      if (currentRequest === requestId.current) { setLoading(false); setRefreshing(false); }
    }
  }, [statusFilter, search]);

  useEffect(() => {
    const timer = setTimeout(() => {
      void load();
    }, 200);
    return () => { clearTimeout(timer); ++requestId.current; };
  }, [load]);

  const handleClose = async (jobId: string, title: string) => {
    if (!window.confirm(`Are you sure you want to take down/close "${title}"?`)) return;
    if (!auth?.currentUser) return;
    setBusyJobId(jobId);
    setError('');
    setNotice('');
    try {
      const token = await auth.currentUser.getIdToken();
      await closeJob(token, jobId);
      setNotice(`Job "${title}" has been closed.`);
      await load(true);
      if (selectedJobId === jobId) setDetailsRefresh((current) => current + 1);
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusyJobId(null);
    }
  };

  const handleReview = async (job: JobRecord, decision: 'approved' | 'rejected') => {
    const notes = decision === 'rejected' ? window.prompt(`Reason for rejecting "${job.title}"?`) : '';
    if (notes === null || (decision === 'rejected' && notes.trim().length < 5)) return;
    if (!auth?.currentUser) return;
    setBusyJobId(job.id); setError(''); setNotice('');
    try {
      const token = await auth.currentUser.getIdToken();
      await reviewJob(token, job.id, decision, notes || '');
      setNotice(`Job "${job.title}" ${decision === 'approved' ? 'is now live' : 'was rejected'}.`);
      await load(true);
      if (selectedJobId === job.id) setDetailsRefresh((current) => current + 1);
    } catch (err) { setError((err as Error).message); }
    finally { setBusyJobId(null); }
  };

  if (selectedJobId) return (
    <section className="job-seeker-detail-page job-detail-page" aria-busy={detailsLoading}>
      <div className="job-seeker-detail-toolbar">
        <button type="button" className="text-button" onClick={() => setSelectedJobId(null)}>← Back to jobs</button>
        <button type="button" className="text-button" disabled={detailsLoading} onClick={() => setDetailsRefresh((current) => current + 1)}>{detailsLoading ? 'Refreshing…' : 'Refresh details'}</button>
      </div>
      {detailsError && <div className="banner error" role="alert">{detailsError}</div>}
      {notice && <div className="banner success" role="status">{notice}</div>}
      {detailsLoading && <div className="panel-loading">Loading job details…</div>}
      {!detailsLoading && !details && <button type="button" className="secondary-button" onClick={() => setDetailsRefresh((current) => current + 1)}>Try again</button>}
      {details && <>
        <header className="job-seeker-profile-header">
          <div className="job-seeker-profile-title"><p className="section-eyebrow">JOB POSTING</p><h2>{details.title}</h2><p>{details.companyName} · {details.locationCity || 'Location not provided'}</p></div>
          <span className={`status-pill pill-${details.status}`}>{statusLabel(details.status)}</span>
        </header>
        <div className="employer-detail-review job-seeker-detail-section">
          <div><h3>Review decision</h3><p>{details.status === 'pending' ? 'Read the full posting before making a decision.' : `This posting is ${statusLabel(details.status).toLowerCase()}.`}</p>
            {details.reviewNotes && <p className="employer-review-reason"><strong>Reason:</strong> {details.reviewNotes}</p>}</div>
          <div className="employer-action-buttons">
            {details.status === 'pending' && <><button type="button" className="row-action" disabled={busyJobId === details.id} onClick={() => void handleReview(details, 'approved')}>Approve job</button><button type="button" className="row-action danger-action" disabled={busyJobId === details.id} onClick={() => void handleReview(details, 'rejected')}>Reject job</button></>}
            {details.status === 'active' && <button type="button" className="row-action danger-action" disabled={busyJobId === details.id} onClick={() => void handleClose(details.id, details.title)}>Take down</button>}
          </div>
        </div>
        <div className="job-seeker-account-meta">
          <DetailField label="Submitted" entry={date(details.postedAt)} /><DetailField label="Reviewed" entry={date(details.reviewedAt)} />
          <DetailField label="Updated" entry={date(details.updatedAt)} /><DetailField label="Expires" entry={date(details.expiresAt)} />
        </div>
        <div className="job-seeker-detail-grid">
          <section className="job-seeker-detail-section"><h3>Job description</h3><p className="job-detail-description">{details.description || 'No description provided.'}</p></section>
          <section className="job-seeker-detail-section"><h3>Role and location</h3><div className="job-seeker-fields">
            <DetailField label="Category" entry={details.category} /><DetailField label="Work mode" entry={details.workMode} />
            <DetailField label="District" entry={details.locationCity} /><DetailField label="Openings" entry={details.vacanciesCount} />
            <DetailField label="Salary" entry={details.salaryText} /><DetailField label="Visibility" entry={details.reach} />
          </div></section>
          <section className="job-seeker-detail-section"><h3>Company and plan</h3><div className="job-seeker-fields">
            <DetailField label="Company" entry={details.companyName} /><DetailField label="Industry" entry={details.companyIndustry} />
            <DetailField label="Company district" entry={details.companyDistrict} /><DetailField label="Employer approval" entry={details.employerReviewState} />
            <DetailField label="Plan" entry={details.planName} /><DetailField label="Plan tier" entry={details.planTier} />
          </div></section>
          <section className="job-seeker-detail-section"><h3>Recruiter contact</h3><div className="job-seeker-fields">
            <DetailField label="Contact name" entry={details.contactName} /><DetailField label="Phone" entry={details.phone} />
            <DetailField label="WhatsApp" entry={details.whatsappNumber} /><DetailField label="Email" entry={details.email} />
          </div></section>
        </div>
      </>}
    </section>
  );

  return (
    <div className="jobs-panel">
      {notice && <div className="banner success">{notice}</div>}
      {error && <div className="banner error">{error}</div>}

      <div className="panel-controls">
        <button type="button" className="text-button panel-refresh" disabled={loading || loadingMore || refreshing} onClick={() => void load(true)}>{refreshing ? 'Refreshing…' : 'Refresh'}</button>
        <div className="filter-tabs">
          {(['pending', 'active', 'closed', 'rejected', 'all'] as const).map((filter) => (
            <button
              key={filter}
              className={`filter-tab ${statusFilter === filter ? 'active' : ''}`}
              onClick={() => setStatusFilter(filter)}
            >
              {filter === 'pending' ? 'Needs review' : filter === 'rejected' ? 'Rejected' : filter === 'active'
                ? 'Active Live Jobs'
                : filter === 'closed'
                ? 'Closed Jobs'
                : 'All Postings'}
            </button>
          ))}
        </div>

        <div className="search-box">
          <input
            type="text"
            aria-label="Search jobs"
            placeholder="Search job title, company, or district..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          {search && (
            <button className="clear-btn" type="button" aria-label="Clear search" onClick={() => setSearch('')}>×</button>
          )}
        </div>
      </div>

      {loading ? (
        <div className="jobs-table-container" aria-busy="true" aria-label="Loading job listings">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Job Title & Company</th>
                <th>Category & Work Mode</th>
                <th>Location & Salary</th>
                <th>Status</th>
                <th>Details</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {[1, 2, 3, 4, 5].map((i) => (
                <tr key={i} className="skeleton-table-row">
                  <td>
                    <span className="skeleton-bone" style={{ width: `${65 - (i % 3) * 10}%`, height: '15px', marginBottom: '6px' }} />
                    <span className="skeleton-bone" style={{ width: '45%', height: '12px' }} />
                  </td>
                  <td>
                    <span className="skeleton-bone" style={{ width: '55%', height: '15px', marginBottom: '6px' }} />
                    <span className="skeleton-bone" style={{ width: '40%', height: '12px' }} />
                  </td>
                  <td>
                    <span className="skeleton-bone" style={{ width: '45%', height: '15px', marginBottom: '6px' }} />
                    <span className="skeleton-bone" style={{ width: '38%', height: '12px' }} />
                  </td>
                  <td>
                    <span className="skeleton-bone" style={{ width: '48px', height: '22px', borderRadius: '4px' }} />
                  </td>
                  <td><span className="skeleton-bone" style={{ width: '80px', height: '30px', borderRadius: '6px' }} /></td>
                  <td>
                    <span className="skeleton-bone" style={{ width: '80px', height: '30px', borderRadius: '6px' }} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : jobs.length === 0 ? (
        <div className="empty-panel">
          <p>{error ? "Jobs could not be loaded. Use Refresh to try again." : "No job postings found."}</p>
        </div>
      ) : (
        <div className="jobs-table-container">
          <table className="admin-table jobs-table">
            <thead>
              <tr>
                <th>Job Title & Company</th>
                <th>Category & Work Mode</th>
                <th>Location & Salary</th>
                <th className="cell-status">Status</th>
                <th>Details</th>
                <th className="cell-actions">Actions</th>
              </tr>
            </thead>
            <tbody>
              {jobs.map((job) => {
                const isBusy = busyJobId === job.id;
                return (
                  <tr key={job.id} className={`row-status-${job.status}`}>
                    <td>
                      <div className="table-title">{job.title}</div>
                      <div className="table-subtitle">{job.companyName}</div>
                    </td>
                    <td>
                      <div>{job.category}</div>
                      <div className="table-subtitle">{job.workMode} · {job.vacanciesCount} opening{job.vacanciesCount === 1 ? '' : 's'}</div>
                    </td>
                    <td>
                      <div>{job.locationCity}</div>
                      <div className="table-subtitle">{job.salaryText}</div>
                    </td>
                    <td className="cell-status">
                      <span className={`status-pill pill-${job.status}`}>
                        {job.status === 'active' ? 'Live' : job.status === 'pending' ? 'Needs review' : job.status === 'rejected' ? 'Rejected' : 'Closed'}
                      </span>
                    </td>
                    <td><button type="button" className="row-action employer-view-button" onClick={() => { setNotice(''); setError(''); setSelectedJobId(job.id); }}>View details</button></td>
                    <td className="cell-actions">
                      {job.status === 'pending' ? (
                        <div style={{display:'flex',gap:8}}><button disabled={isBusy} onClick={() => void handleReview(job, 'approved')}>Approve</button><button disabled={isBusy} onClick={() => void handleReview(job, 'rejected')}>Reject</button></div>
                      ) : job.status === 'active' ? (
                        <button
                          className="danger-button-sm"
                          disabled={isBusy}
                          onClick={() => void handleClose(job.id, job.title)}
                        >
                          {isBusy ? 'Closing...' : 'Take Down'}
                        </button>
                      ) : (
                        <span className="text-muted">Closed</span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
      {!loading && nextCursor && (
        <div className="pagination-row"><button className="text-button" disabled={loadingMore} onClick={async () => {
          if (!auth?.currentUser || !nextCursor) return;
          const currentRequest = requestId.current;
          try {
            setLoadingMore(true);
            const result = await listJobs(await auth.currentUser.getIdToken(), statusFilter, search, nextCursor);
            if (currentRequest !== requestId.current) return;
            setJobs((current) => [...current, ...result.jobs]);
            setNextCursor(result.nextCursor);
          } catch (err) { if (currentRequest === requestId.current) setError((err as Error).message); }
          finally { setLoadingMore(false); }
        }}>{loadingMore ? 'Loading more…' : 'Load more jobs'}</button></div>
      )}
    </div>
  );
}
