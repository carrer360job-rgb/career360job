import { useEffect, useState, useCallback } from 'react';
import { listEmployers, reviewEmployer, type EmployerRecord } from './api';
import { auth } from './firebase';

export default function EmployersPanel() {
  const [employers, setEmployers] = useState<EmployerRecord[]>([]);
  const [statusFilter, setStatusFilter] = useState<'approved' | 'rejected' | 'all'>('approved');
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [busyUid, setBusyUid] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [suspendingUid, setSuspendingUid] = useState<string | null>(null);
  const [suspendReason, setSuspendReason] = useState('');

  const load = useCallback(async () => {
    if (!auth?.currentUser) return;
    try {
      setLoading(true);
      const token = await auth.currentUser.getIdToken();
      const res = await listEmployers(token, statusFilter, search);
      setEmployers(res.employers);
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
      setNotice(
        decision === 'approved'
          ? 'Company reactivated successfully.'
          : 'Company has been suspended and restricted from posting.'
      );
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
          {(['approved', 'rejected', 'all'] as const).map((filter) => (
            <button
              key={filter}
              className={`filter-tab ${statusFilter === filter ? 'active' : ''}`}
              onClick={() => setStatusFilter(filter)}
            >
              {filter === 'approved'
                ? 'Active Companies'
                : filter === 'rejected'
                ? 'Suspended / Flagged'
                : 'All Accounts'}
            </button>
          ))}
        </div>

        <div className="search-box">
          <input
            type="text"
            placeholder="Search company, phone, contact or district…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          {search && (
            <button className="clear-btn" onClick={() => setSearch('')}>✕</button>
          )}
        </div>
      </div>

      {loading ? (
        <div className="panel-loading">Loading company directory…</div>
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
                      ? '✔ Active'
                      : emp.status === 'rejected'
                      ? '✖ Suspended'
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
                        placeholder="Reason for suspension (e.g. Scammer, illegal fee asked, fake job)"
                        value={suspendReason}
                        onChange={(e) => setSuspendReason(e.target.value)}
                        autoFocus
                      />
                      <div className="rejection-form-buttons">
                        <button
                          className="danger-button"
                          disabled={isBusy}
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
                          ✖ Suspend Company
                        </button>
                      ) : (
                        <button
                          className="approve-button"
                          disabled={isBusy}
                          onClick={() => void handleModeration(emp.uid, 'approved')}
                        >
                          {isBusy ? 'Reactivating…' : '✔ Reactivate Company'}
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
    </div>
  );
}
