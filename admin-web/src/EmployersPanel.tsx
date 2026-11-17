import { useEffect, useState, useCallback } from 'react';
import { listEmployers, reviewEmployer, type EmployerRecord } from './api';
import { auth } from './supabase';

export default function EmployersPanel() {
  const [employers, setEmployers] = useState<EmployerRecord[]>([]);
  const [statusFilter, setStatusFilter] = useState<'pending' | 'approved' | 'rejected' | 'all'>('pending');
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [busyUid, setBusyUid] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [suspendingUid, setSuspendingUid] = useState<string | null>(null);
  const [suspendReason, setSuspendReason] = useState('');
  const [nextCursor, setNextCursor] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!auth?.currentUser) return;
    try {
      setLoading(true);
      const token = await auth.currentUser.getIdToken();
      const res = await listEmployers(token, statusFilter, search);
      setEmployers(res.employers);
      setNextCursor(res.nextCursor);
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

  const handleModeration = async (uid: string, decision: 'approved' | 'rejected', notes?: string) => {
    if (!auth?.currentUser) return;
    setBusyUid(uid);
    setError('');
    setNotice('');
    try {
      const token = await auth.currentUser.getIdToken();
      await reviewEmployer(token, uid, decision, notes);
      const previousStatus = employers.find((employer) => employer.uid === uid)?.status;
      setNotice(decision === 'approved'
        ? previousStatus === 'pending' ? 'Company approved.' : 'Company reactivated.'
        : previousStatus === 'pending' ? 'Application rejected.' : 'Company suspended.');
      setSuspendingUid(null);
      setSuspendReason('');
      await load();
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusyUid(null);
    }
  };

  return (
    <div className="employers-panel">
      {notice && <div className="banner success">{notice}</div>}
      {error && <div className="banner error">{error}</div>}

      {/* Filter and Search Bar */}
      <div className="panel-controls">
        <div className="filter-tabs">
          {(['pending', 'approved', 'rejected', 'all'] as const).map((filter) => (
            <button
              key={filter}
              className={`filter-tab ${statusFilter === filter ? 'active' : ''}`}
              onClick={() => setStatusFilter(filter)}
            >
              {filter === 'pending' ? 'Needs review' : filter === 'approved' ? 'Approved' : filter === 'rejected' ? 'Rejected / suspended' : 'All companies'}
            </button>
          ))}
        </div>

        <div className="search-box">
          <input
            aria-label="Search companies"
            type="text"
            placeholder="Search company, phone, contact or districtâ€¦"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          {search && (
            <button className="clear-btn" type="button" aria-label="Clear search" onClick={() => setSearch('')}>×</button>
          )}
        </div>
      </div>

      {loading ? (
        <div className="panel-loading">Loading company directoryâ€¦</div>
      ) : employers.length === 0 ? (
        <div className="empty-panel">
          <p>No companies found in this section.</p>
        </div>
      ) : (
        <div className="company-cards-grid">
          {employers.map((emp) => {
            const isBusy = busyUid === emp.uid;
            return (
              <div key={emp.uid} className={`company-card status-${emp.status}`}>
                <div className="company-card-header">
                  <div>
                    <h3 className="company-title">{emp.companyName || 'Unnamed Business'}</h3>
                    <span className="industry-pill">{emp.industry || 'General Business'}</span>
                    <span className="location-pill">{emp.district ? `${emp.district}, ${emp.state}` : 'Tamil Nadu'}</span>
                  </div>
                  <span className={`status-pill pill-${emp.status}`}>
                    {emp.status === 'approved'
                      ? 'âœ” Active'
                      : emp.status === 'rejected'
                      ? 'âœ– Suspended'
                      : 'â³ Pending'}
                  </span>
                </div>

                <div className="company-details-grid">
                  <div className="detail-item">
                    <span className="detail-label">Recruiter / Contact</span>
                    <span className="detail-value">{emp.contactName} ({emp.designation || 'HR'})</span>
                  </div>
                  <div className="detail-item">
                    <span className="detail-label">Phone & WhatsApp</span>
                    <span className="detail-value">
                      <a href={`tel:${emp.phone}`}>{emp.phone}</a>
                      {emp.whatsappPhone && emp.whatsappPhone !== emp.phone && (
                        <span> Â· WA: <a href={`https://wa.me/91${emp.whatsappPhone}`} target="_blank" rel="noreferrer">{emp.whatsappPhone}</a></span>
                      )}
                    </span>
                  </div>
                  <div className="detail-item">
                    <span className="detail-label">Account Email</span>
                    <span className="detail-value">{emp.email}</span>
                  </div>
                  <div className="detail-item">
                    <span className="detail-label">GSTIN / Registration</span>
                    <span className="detail-value">{emp.registrationNumber || 'Not provided'}</span>
                  </div>
                  <div className="detail-item full-width">
                    <span className="detail-label">Address</span>
                    <span className="detail-value">{emp.address || 'Address not provided'} {emp.postalCode ? `- ${emp.postalCode}` : ''}</span>
                  </div>
                  {emp.rejectionReason && (
                    <div className="detail-item full-width rejection-box">
                      <span className="detail-label">Suspension Reason</span>
                      <span className="detail-value">{emp.rejectionReason}</span>
                    </div>
                  )}
                  {emp.status === 'approved' && (
                    <div className="detail-item full-width approved-box">
                      <span className="detail-label">Plan & Posting Status</span>
                      <span className="detail-value">
                        {emp.postingCredits} posting credit{emp.postingCredits === 1 ? '' : 's'} available (Plan: {emp.activePlan})
                      </span>
                    </div>
                  )}
                </div>

                {/* Moderation Actions */}
                <div className="company-card-actions">
                  {suspendingUid === emp.uid ? (
                    <div className="rejection-form">
                      <input
                        type="text"
                        aria-label="Reason for rejection or suspension"
                        required
                        placeholder="Reason for suspension (e.g. Scammer, illegal fee asked, fake job)"
                        value={suspendReason}
                        onChange={(e) => setSuspendReason(e.target.value)}
                        autoFocus
                      />
                      <div className="rejection-form-buttons">
                        <button
                          className="danger-button"
                          disabled={isBusy || suspendReason.trim().length < 3}
                          onClick={() => void handleModeration(emp.uid, 'rejected', suspendReason)}
                        >
                          Confirm Suspend
                        </button>
                        <button
                          className="text-button"
                          onClick={() => { setSuspendingUid(null); setSuspendReason(''); }}
                        >
                          Cancel
                        </button>
                      </div>
                    </div>
                  ) : (
                    <>
                      {emp.status === 'approved' ? (
                        <button
                          className="reject-button"
                          disabled={isBusy}
                          onClick={() => setSuspendingUid(emp.uid)}
                        >
                          âœ– Suspend Company
                        </button>
                      ) : (
                        <button
                          className="approve-button"
                          disabled={isBusy}
                          onClick={() => void handleModeration(emp.uid, 'approved')}
                        >
                          {isBusy ? 'Updating...' : emp.status === 'pending' ? 'Approve company' : 'Reactivate company'}
                        </button>
                      )}
                      {emp.status === 'pending' && (
                        <button className="reject-button" disabled={isBusy} onClick={() => setSuspendingUid(emp.uid)}>
                          Reject application
                        </button>
                      )}
                    </>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
      {!loading && nextCursor && (
        <div className="pagination-row"><button className="text-button" onClick={async () => {
          if (!auth?.currentUser || !nextCursor) return;
          try {
            setLoading(true);
            const result = await listEmployers(await auth.currentUser.getIdToken(), statusFilter, search, nextCursor);
            setEmployers((current) => [...current, ...result.employers]);
            setNextCursor(result.nextCursor);
          } catch (err) { setError((err as Error).message); }
          finally { setLoading(false); }
        }}>Load more companies</button></div>
      )}
    </div>
  );
}
