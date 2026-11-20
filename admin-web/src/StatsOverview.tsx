import { useCallback, useEffect, useRef, useState } from 'react';
import { getStats, listEmployers, type EmployerRecord, type PlatformStats } from './api';
import { getAccessToken } from './supabase';

type Destination = 'employers' | 'jobs' | 'jobseekers' | 'plans' | 'reports' | 'payments';
type QueueItem = { id: string; title: string; detail: string; kind: string; destination: Destination };

function shortDate(value: string | null | undefined) {
  if (!value) return 'Date unavailable';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? 'Date unavailable' : new Intl.DateTimeFormat('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }).format(date);
}

export default function StatsOverview({ onNavigateTab }: { onNavigateTab: (tab: Destination) => void }) {
  const [stats, setStats] = useState<PlatformStats | null>(null);
  const [employers, setEmployers] = useState<EmployerRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [queueError, setQueueError] = useState(false);
  const initialLoadStarted = useRef(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    setQueueError(false);
    try {
      const token = await getAccessToken();
      if (!token) throw new Error('Your session has expired. Sign in again.');
      const [statsResult, employerResult] = await Promise.allSettled([
        getStats(token), listEmployers(token, 'pending'),
      ]);
      if (statsResult.status === 'fulfilled') setStats(statsResult.value);
      else setError(statsResult.reason instanceof Error ? statsResult.reason.message : 'Could not load platform metrics.');
      if (employerResult.status === 'fulfilled') setEmployers(employerResult.value.employers);
      setQueueError(employerResult.status === 'rejected');
    } catch (caught) { setError((caught as Error).message); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => {
    if (initialLoadStarted.current) return;
    initialLoadStarted.current = true;
    void load();
  }, [load]);

  const queue: QueueItem[] = [
    ...employers.map((employer) => ({ id: `employer-${employer.uid}`, title: employer.companyName || 'Unnamed company', detail: `Employer review · ${shortDate(employer.createdAt)}`, kind: 'Company', destination: 'employers' as const })),
  ].slice(0, 6);

  const metrics: { label: string; value: number | undefined; note: string; destination: Destination }[] = [
    { label: 'Awaiting review', value: stats?.pendingEmployers, note: 'Employer accounts', destination: 'employers' },
    { label: 'Active employers', value: stats?.approvedEmployers, note: stats ? `${stats.totalEmployers} registered` : 'Registered employers', destination: 'employers' },
    { label: 'Live jobs', value: stats?.activeJobs, note: stats ? `${stats.totalJobs} total listings` : 'Total listings', destination: 'jobs' },
    { label: 'Job seekers', value: stats?.totalCandidates, note: 'Registered candidates', destination: 'jobseekers' },
  ];

  return <div className="overview-content" aria-busy={loading}>
    <div className="overview-section-heading"><div><h2>Platform at a glance</h2><p>Current activity and work that needs a decision.</p></div><button type="button" className="text-button" disabled={loading} onClick={() => void load()}>{loading ? 'Refreshing...' : 'Refresh data'}</button></div>
    {error && <div className="banner error" role="alert">{error} <button className="inline-retry" type="button" disabled={loading} onClick={() => void load()}>Try again</button></div>}
    <div className="metric-grid">
      {metrics.map((metric) => <button className="metric-card" key={metric.label} type="button" onClick={() => onNavigateTab(metric.destination)}>
        <span className="metric-label">{metric.label}</span>
        {loading && metric.value === undefined ? (
          <span className="skeleton-bone skeleton-metric-val" aria-hidden="true" />
        ) : (
          <strong className="metric-value">{metric.value ?? '—'}</strong>
        )}
        <span className="metric-bottom">{metric.note}<span aria-hidden="true">↗</span></span>
      </button>)}
    </div>
    <div className="overview-columns">
      <section className="work-panel" aria-labelledby="queue-title">
        <div className="work-panel-heading"><div><p className="section-eyebrow">PRIORITY</p><h2 id="queue-title">Needs attention</h2></div><span className="queue-count">{loading && !queue.length ? '—' : queue.length}</span></div>
        {queueError && <p className="queue-warning">Some review items could not be loaded. Refresh to try again.</p>}
        {loading && !queue.length ? (
          <div className="queue-list" aria-busy="true" aria-label="Loading review queue">
            {[1, 2, 3].map((i) => (
              <div key={i} className="queue-row" style={{ pointerEvents: 'none' }}>
                <span className="skeleton-bone" style={{ width: '8px', height: '8px', borderRadius: '50%', flexShrink: 0 }} />
                <div className="queue-text" style={{ flex: 1, padding: '0 4px' }}>
                  <span className="skeleton-bone" style={{ width: `${58 - i * 6}%`, height: '14px', marginBottom: '6px' }} />
                  <span className="skeleton-bone" style={{ width: '42%', height: '11px' }} />
                </div>
                <span className="skeleton-bone" style={{ width: '56px', height: '18px', borderRadius: '4px' }} />
              </div>
            ))}
          </div>
        ) : queueError && !queue.length ? (
          <p className="queue-empty">Employer reviews are unavailable right now.</p>
        ) : queue.length === 0 ? (
          <div className="queue-empty"><strong>All clear for now</strong><p>New employer reviews will appear here.</p></div>
        ) : (
          <div className="queue-list">
            {queue.map((item) => <button className="queue-row" key={item.id} type="button" onClick={() => onNavigateTab(item.destination)}><span className="queue-mark"/><span className="queue-text"><strong>{item.title}</strong><small>{item.detail}</small></span><span className="queue-kind">{item.kind}</span><span className="queue-arrow" aria-hidden="true">→</span></button>)}
          </div>
        )}
      </section>
      <section className="work-panel snapshot-panel" aria-labelledby="snapshot-title"><div className="work-panel-heading"><div><p className="section-eyebrow">ACTIVITY</p><h2 id="snapshot-title">Platform snapshot</h2></div></div>
        <div className="snapshot-line"><span>Applications recorded</span><strong>{loading && !stats ? <span className="skeleton-bone" style={{ display: 'inline-block', width: '38px', height: '18px' }} /> : (stats?.totalApplications ?? '—')}</strong></div>
        <div className="snapshot-line"><span>Closed listings</span><strong>{loading && !stats ? <span className="skeleton-bone" style={{ display: 'inline-block', width: '38px', height: '18px' }} /> : (stats?.closedJobs ?? '—')}</strong></div>
        <div className="snapshot-line"><span>Rejected or suspended employers</span><strong>{loading && !stats ? <span className="skeleton-bone" style={{ display: 'inline-block', width: '38px', height: '18px' }} /> : (stats?.rejectedEmployers ?? '—')}</strong></div>
        <div className="snapshot-actions"><button type="button" onClick={() => onNavigateTab('employers')}>Review employer accounts <span aria-hidden="true">→</span></button></div>
      </section>
    </div>
  </div>;
}
