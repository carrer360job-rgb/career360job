import { useEffect, useState, useCallback, useRef } from 'react';
import { listEmployers, reviewEmployer, type EmployerRecord } from './api';
import { auth } from './supabase';

export default function EmployersPanel() {
  const [employers, setEmployers] = useState<EmployerRecord[]>([]);
  const [statusFilter, setStatusFilter] = useState<'pending' | 'approved' | 'rejected' | 'all'>('pending');
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const requestId = useRef(0);
  const [busyUid, setBusyUid] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [suspendingUid, setSuspendingUid] = useState<string | null>(null);
  const [suspendReason, setSuspendReason] = useState('');
  const [nextCursor, setNextCursor] = useState<string | null>(null);

  const load = useCallback(async (background = false) => {
    const currentRequest = ++requestId.current;
    try {
      if (background) setRefreshing(true); else { setRefreshing(false); setLoading(true); }
      const token = await auth.currentUser.getIdToken();
      const res = await listEmployers(token, statusFilter, search);
      if (currentRequest !== requestId.current) return;
      setEmployers(res.employers);
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
      await load(true);
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
        <button type="button" className="text-button panel-refresh" disabled={loading || loadingMore || refreshing} onClick={() => void load(true)}>{refreshing ? 'Refreshing…' : 'Refresh'}</button>
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
            placeholder="Search company, phone, contact or district..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          {search && (
            <button className="clear-btn" type="button" aria-label="Clear search" onClick={() => setSearch('')}>×</button>
          )}
        </div>
      </div>

      {loading ? (
        <div className="company-cards-grid" aria-busy="true" aria-label="Loading company directory">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="company-card skeleton-card">
              <div className="company-card-header">
                <div style={{ flex: 1 }}>
                  <span className="skeleton-bone" style={{ width: `${58 - (i % 2) * 12}%`, height: '20px', marginBottom: '10px' }} />
                  <div style={{ display: 'flex', gap: '6px' }}>
                    <span className="skeleton-bone" style={{ width: '80px', height: '20px', borderRadius: '4px' }} />
                    <span className="skeleton-bone" style={{ width: '100px', height: '20px', borderRadius: '4px' }} />
                  </div>
                </div>
                <span className="skeleton-bone" style={{ width: '74px', height: '22px', borderRadius: '4px' }} />
              </div>

              <div className="company-details-grid">
                <div className="detail-item">
                  <span className="skeleton-bone" style={{ width: '90px', height: '10px', marginBottom: '8px' }} />
                  <span className="skeleton-bone" style={{ width: '130px', height: '15px' }} />
                </div>
                <div className="detail-item">
                  <span className="skeleton-bone" style={{ width: '95px', height: '10px', marginBottom: '8px' }} />
                  <span className="skeleton-bone" style={{ width: '115px', height: '15px' }} />
                </div>
                <div className="detail-item">
                  <span className="skeleton-bone" style={{ width: '80px', height: '10px', marginBottom: '8px' }} />
                  <span className="skeleton-bone" style={{ width: '150px', height: '15px' }} />
                </div>
                <div className="detail-item">
                  <span className="skeleton-bone" style={{ width: '110px', height: '10px', marginBottom: '8px' }} />
                  <span className="skeleton-bone" style={{ width: '100px', height: '15px' }} />
                </div>
                <div className="detail-item full-width">
                  <span className="skeleton-bone" style={{ width: '60px', height: '10px', marginBottom: '8px' }} />
                  <span className="skeleton-bone" style={{ width: '85%', height: '15px' }} />
                </div>
              </div>

              <div className="company-card-actions" style={{ display: 'flex', gap: '8px', paddingTop: '12px', borderTop: '1px solid #f0f3f6' }}>
                <span className="skeleton-bone" style={{ width: '120px', height: '36px', borderRadius: '6px' }} />
                <span className="skeleton-bone" style={{ width: '100px', height: '36px', borderRadius: '6px' }} />
              </div>
            </div>
          ))}
        </div>
      ) : employers.length === 0 ? (
        <div className="empty-panel">
          <p>{error ? "Companies could not be loaded. Use Refresh to try again." : "No companies found in this section."}</p>
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
                      ? '✓ Active'
                      : emp.status === 'rejected'
                      ? '✕ Suspended'
                      : '⏳ Pending'}
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
                        <span> · WA: <a href={`https://wa.me/91${emp.whatsappPhone}`} target="_blank" rel="noreferrer">{emp.whatsappPhone}</a></span>
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
                          ✕ Suspend Company
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
        <div className="pagination-row"><button className="text-button" disabled={loadingMore} onClick={async () => {
          if (!auth?.currentUser || !nextCursor) return;
          const currentRequest = requestId.current;
          try {
            setLoadingMore(true);
            const result = await listEmployers(await auth.currentUser.getIdToken(), statusFilter, search, nextCursor);
            if (currentRequest !== requestId.current) return;
            setEmployers((current) => [...current, ...result.employers]);
            setNextCursor(result.nextCursor);
          } catch (err) { if (currentRequest === requestId.current) setError((err as Error).message); }
          finally { setLoadingMore(false); }
        }}>{loadingMore ? 'Loading more…' : 'Load more companies'}</button></div>
      )}
    </div>
  );
}
