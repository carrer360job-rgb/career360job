import { useEffect, useState } from 'react';
import { getStats, type PlatformStats } from './api';
import { auth } from './firebase';

export default function StatsOverview({ onNavigateTab }: { onNavigateTab: (tab: 'employers' | 'jobs' | 'plans') => void }) {
  const [stats, setStats] = useState<PlatformStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = async () => {
    if (!auth?.currentUser) return;
    try {
      const token = await auth.currentUser.getIdToken();
      const data = await getStats(token);
      setStats(data);
      setError('');
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, []);

  if (loading) {
    return <div className="panel-loading">Loading platform metrics…</div>;
  }

  if (error) {
    return (
      <div className="banner error">
        <span>{error}</span>
        <button className="text-button" onClick={() => void load()}>Retry</button>
      </div>
    );
  }

  if (!stats) return null;

  return (
    <div className="stats-container">
      <div className="stats-grid">
        {/* Active Companies Card */}
        <div
          className="stat-card"
          onClick={() => onNavigateTab('employers')}
          style={{ cursor: 'pointer' }}
        >
          <div className="stat-header">
            <span className="stat-label">Active Companies</span>
            <span className="stat-badge success">Verified</span>
          </div>
          <div className="stat-value">{stats.approvedEmployers}</div>
          <div className="stat-footer">
            <span>{stats.totalEmployers} total registered</span>
            <span className="stat-arrow">→</span>
          </div>
        </div>

        {/* Live Jobs Card */}
        <div
          className="stat-card"
          onClick={() => onNavigateTab('jobs')}
          style={{ cursor: 'pointer' }}
        >
          <div className="stat-header">
            <span className="stat-label">Active Live Jobs</span>
            <span className="stat-badge success">Live in TN</span>
          </div>
          <div className="stat-value">{stats.activeJobs}</div>
          <div className="stat-footer">
            <span>{stats.totalJobs} total jobs published</span>
            <span className="stat-arrow">→</span>
          </div>
        </div>

        {/* Total Candidates Card */}
        <div className="stat-card">
          <div className="stat-header">
            <span className="stat-label">Registered Job Seekers</span>
          </div>
          <div className="stat-value">{stats.totalCandidates}</div>
          <div className="stat-footer">
            <span>Direct contact enabled</span>
          </div>
        </div>

        {/* Applications Recorded */}
        <div className="stat-card">
          <div className="stat-header">
            <span className="stat-label">Direct Inquiries Recorded</span>
          </div>
          <div className="stat-value">{stats.totalApplications}</div>
          <div className="stat-footer">
            <span>Across all listings</span>
          </div>
        </div>
      </div>

      <div className="action-banner">
        <div>
          <strong>Frictionless Direct Hiring Mode Active</strong>
          <p>Companies are automatically approved with 1 Free Job Post on registration. Use the Companies tab to monitor or suspend abusive accounts.</p>
        </div>
        <button className="primary-button" onClick={() => onNavigateTab('jobs')}>
          View Live Jobs
        </button>
      </div>
    </div>
  );
}
