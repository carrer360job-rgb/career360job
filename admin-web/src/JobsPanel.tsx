import { useEffect, useState, useCallback } from 'react';
import { listJobs, closeJob, type JobRecord } from './api';
import { auth } from './firebase';

export default function JobsPanel() {
  const [jobs, setJobs] = useState<JobRecord[]>([]);
  const [statusFilter, setStatusFilter] = useState<'active' | 'closed' | 'all'>('active');
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [busyJobId, setBusyJobId] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  const load = useCallback(async () => {
    if (!auth?.currentUser) return;
    try {
      setLoading(true);
      const token = await auth.currentUser.getIdToken();
      const res = await listJobs(token, statusFilter, search);
      setJobs(res.jobs);
      setError('');
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setLoading(false);
    }
  }, [statusFilter, search]);

  useEffect(() => {
    const timer = setTimeout(() => {
      void load();
    }, 200);
    return () => clearTimeout(timer);
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
      await load();
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
            placeholder="Search job title, company, or district…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          {search && (
            <button className="clear-btn" onClick={() => setSearch('')}>✕</button>
          )}
        </div>
      </div>

      {loading ? (
        <div className="panel-loading">Loading job listings…</div>
      ) : jobs.length === 0 ? (
        <div className="empty-panel">
          <p>No job postings found.</p>
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
                          {isBusy ? 'Closing…' : 'Take Down'}
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
    </div>
  );
}
