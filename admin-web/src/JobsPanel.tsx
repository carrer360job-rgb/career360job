import { useEffect, useState, useCallback, useRef } from 'react';
import { listJobs, closeJob, type JobRecord } from './api';
import { auth } from './supabase';

export default function JobsPanel() {
  const [jobs, setJobs] = useState<JobRecord[]>([]);
  const [statusFilter, setStatusFilter] = useState<'active' | 'closed' | 'all'>('active');
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const requestId = useRef(0);
  const [busyJobId, setBusyJobId] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [nextCursor, setNextCursor] = useState<string | null>(null);

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
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusyJobId(null);
    }
  };

  return (
    <div className="jobs-panel">
      {notice && <div className="banner success">{notice}</div>}
      {error && <div className="banner error">{error}</div>}

      <div className="panel-controls">
        <button type="button" className="text-button panel-refresh" disabled={loading || loadingMore || refreshing} onClick={() => void load(true)}>{refreshing ? 'Refreshing…' : 'Refresh'}</button>
        <div className="filter-tabs">
          {(['active', 'closed', 'all'] as const).map((filter) => (
            <button
              key={filter}
              className={`filter-tab ${statusFilter === filter ? 'active' : ''}`}
              onClick={() => setStatusFilter(filter)}
            >
              {filter === 'active'
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
                <th>Direct Recruiter Contact</th>
                <th>Status</th>
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
                    <span className="skeleton-bone" style={{ width: '50%', height: '15px', marginBottom: '6px' }} />
                    <span className="skeleton-bone" style={{ width: '42%', height: '12px' }} />
                  </td>
                  <td>
                    <span className="skeleton-bone" style={{ width: '48px', height: '22px', borderRadius: '4px' }} />
                  </td>
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
          <table className="admin-table">
            <thead>
              <tr>
                <th>Job Title & Company</th>
                <th>Category & Work Mode</th>
                <th>Location & Salary</th>
                <th>Direct Recruiter Contact</th>
                <th>Status</th>
                <th>Actions</th>
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
                    <td>
                      <div>{job.contactName || 'Recruiter'}</div>
                      <div className="table-subtitle">
                        {job.phone && <a href={`tel:${job.phone}`}>{job.phone}</a>}
                        {job.whatsappNumber && (
                          <span> · <a href={`https://wa.me/91${job.whatsappNumber}`} target="_blank" rel="noreferrer">WA</a></span>
                        )}
                      </div>
                    </td>
                    <td>
                      <span className={`status-pill pill-${job.status}`}>
                        {job.status === 'active' ? 'Live' : 'Closed'}
                      </span>
                    </td>
                    <td>
                      {job.status === 'active' ? (
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
