import { useEffect, useRef, useState, type ReactNode } from 'react';
import type { AdminIdentity } from './api';
import './dashboard.css';

export type AdminTab = 'overview' | 'employers' | 'jobs' | 'jobseekers' | 'plans' | 'payments' | 'reports' | 'settings';

type Props = {
  identity: AdminIdentity;
  activeTab: AdminTab;
  onTabChange: (tab: AdminTab) => void;
  onSignOut: () => void;
  children: ReactNode;
};

const groups: { label: string; items: { key: AdminTab; label: string; icon: string }[] }[] = [
  { label: 'Workspace', items: [
    { key: 'overview', label: 'Overview', icon: 'grid' },
    { key: 'employers', label: 'Employers', icon: 'building' },
    { key: 'jobs', label: 'Jobs', icon: 'briefcase' },
    { key: 'jobseekers', label: 'Job Seekers', icon: 'people' },
  ] },
  { label: 'Commerce', items: [
    { key: 'plans', label: 'Hiring plans', icon: 'layers' },
    { key: 'payments', label: 'Payments', icon: 'receipt' },
  ] },
  { label: 'Platform', items: [
    { key: 'reports', label: 'Reports', icon: 'flag' },
    { key: 'settings', label: 'Settings', icon: 'settings' },
  ] },
];

const copy: Record<AdminTab, { title: string; description: string }> = {
  overview: { title: 'Overview', description: 'A clear view of what needs attention across Career360.' },
  employers: { title: 'Employers', description: 'Review companies and manage access to hiring.' },
  jobs: { title: 'Jobs', description: 'Review live listings and take action on unsafe posts.' },
  jobseekers: { title: 'Job Seekers', description: 'Find candidate accounts and manage access to Career360.' },
  plans: { title: 'Hiring plans', description: 'Set the offers employers see in the app.' },
  payments: { title: 'Payments', description: 'Track orders, payment status, and refunds.' },
  reports: { title: 'Reports', description: 'Resolve reported listings and review platform totals.' },
  settings: { title: 'Settings', description: 'Manage the password for your admin account.' },
};

function Icon({ name, size = 19 }: { name: string; size?: number }) {
  const paths: Record<string, ReactNode> = {
    grid: <><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></>,
    building: <><rect x="4" y="3" width="16" height="18" rx="2"/><path d="M9 21v-4h6v4M8 8h2m4 0h2M8 12h2m4 0h2"/></>,
    briefcase: <><rect x="3" y="7" width="18" height="14" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 13c5 3 13 3 18 0"/></>,
    people: <><circle cx="9" cy="8" r="3"/><path d="M3 20v-2a6 6 0 0 1 12 0v2H3Zm12-14a3 3 0 0 1 0 6m2 3a5 5 0 0 1 4 5h-4"/></>,
    layers: <><rect x="4" y="4" width="16" height="5" rx="1"/><rect x="4" y="11" width="16" height="5" rx="1"/><path d="M4 19h16"/></>,
    receipt: <><path d="M5 3h14v18l-3-2-4 2-4-2-3 2V3Z"/><path d="M9 8h6m-6 4h6"/></>,
    flag: <><path d="M5 21V4m0 1c6-4 8 3 15-1v11c-7 4-9-3-15 1"/></>,
    settings: <><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .34 1.87l.06.06-2.8 2.8-.06-.06A1.7 1.7 0 0 0 15 19.4a1.7 1.7 0 0 0-1 1.56V21h-4v-.04a1.7 1.7 0 0 0-1-1.56 1.7 1.7 0 0 0-1.87.34l-.06.06-2.8-2.8.06-.06A1.7 1.7 0 0 0 4.6 15a1.7 1.7 0 0 0-1.56-1H3v-4h.04A1.7 1.7 0 0 0 4.6 9a1.7 1.7 0 0 0-.34-1.87L4.2 7.07l2.87-2.87.06.06A1.7 1.7 0 0 0 9 4.6a1.7 1.7 0 0 0 1-1.56V3h4v.04A1.7 1.7 0 0 0 15 4.6a1.7 1.7 0 0 0 1.87-.34l.06-.06 2.87 2.87-.06.06A1.7 1.7 0 0 0 19.4 9a1.7 1.7 0 0 0 1.56 1H21v4h-.04A1.7 1.7 0 0 0 19.4 15Z"/></>,
    menu: <path d="M4 6h16M4 12h16M4 18h16"/>,
    close: <path d="M5 5l14 14M19 5 5 19"/>,
    exit: <><path d="M10 4H5a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h5M15 7l5 5-5 5m5-5H9"/></>,
  };
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{paths[name]}</svg>;
}

export default function AdminDashboard({ identity, activeTab, onTabChange, onSignOut, children }: Props) {
  const [menuOpen, setMenuOpen] = useState(false);
  const menuButton = useRef<HTMLButtonElement>(null);
  const closeButton = useRef<HTMLButtonElement>(null);
  const wasMenuOpen = useRef(false);
  useEffect(() => { setMenuOpen(false); }, [activeTab]);
  useEffect(() => {
    if (menuOpen) closeButton.current?.focus();
    else if (wasMenuOpen.current) menuButton.current?.focus();
    wasMenuOpen.current = menuOpen;
  }, [menuOpen]);
  useEffect(() => {
    if (!menuOpen) return;
    const close = (event: KeyboardEvent) => { if (event.key === 'Escape') setMenuOpen(false); };
    window.addEventListener('keydown', close);
    return () => window.removeEventListener('keydown', close);
  }, [menuOpen]);

  return <div className="admin-shell">
    {menuOpen && <button className="sidebar-scrim" type="button" aria-label="Close navigation" onClick={() => setMenuOpen(false)} />}
    <aside className={`admin-sidebar${menuOpen ? ' is-open' : ''}`} aria-label="Admin navigation">
      <div className="sidebar-brand">
        <img src="/career360-icon.png" alt="" width="38" height="38" />
        <div><strong>Career<span>360</span></strong><small>ADMIN CONSOLE</small></div>
        <button ref={closeButton} className="mobile-close" type="button" aria-label="Close navigation" onClick={() => setMenuOpen(false)}><Icon name="close" /></button>
      </div>
      <nav className="sidebar-nav" aria-label="Main navigation">
        {groups.map((group) => <div className="nav-group" key={group.label}>
          <p className="nav-group-label">{group.label}</p>
          {group.items.map((item) => <button key={item.key} type="button" className={`sidebar-link${activeTab === item.key ? ' is-active' : ''}`}
            aria-current={activeTab === item.key ? 'page' : undefined} onClick={() => onTabChange(item.key)}>
            <Icon name={item.icon}/><span>{item.label}</span>
          </button>)}
        </div>)}
      </nav>
      <div className="sidebar-footer"><span className="sidebar-footer-mark" /> Career360 operations</div>
    </aside>
    <div className="admin-workspace">
      <header className="workspace-topbar">
        <div className="topbar-start">
          <button ref={menuButton} type="button" className="mobile-menu" aria-label="Open navigation" aria-expanded={menuOpen} onClick={() => setMenuOpen(true)}><Icon name="menu" size={21}/></button>
          <span className="topbar-context">Career360 <span>/</span> {copy[activeTab].title}</span>
        </div>
        <div className="topbar-account"><span className="account-avatar" aria-hidden="true">{identity.email.charAt(0).toUpperCase()}</span><span className="account-name" title={identity.email}>{identity.email}</span><button type="button" className="topbar-signout" onClick={onSignOut} aria-label="Sign out"><Icon name="exit" size={18}/><span>Sign out</span></button></div>
      </header>
      <main className="workspace-main" id="main-content">
        <div className="page-heading"><div><p className="page-kicker">ADMIN WORKSPACE</p><h1>{copy[activeTab].title}</h1><p>{copy[activeTab].description}</p></div></div>
        {children}
      </main>
    </div>
  </div>;
}

export function AdminDashboardSkeleton({ activeTab = 'overview' }: { activeTab?: AdminTab }) {
  return (
    <div className="admin-shell" aria-busy="true">
      <aside className="admin-sidebar" aria-label="Admin navigation loading">
        <div className="sidebar-brand">
          <img src="/career360-icon.png" alt="" width="38" height="38" />
          <div><strong>Career<span>360</span></strong><small>ADMIN CONSOLE</small></div>
        </div>
        <nav className="sidebar-nav" aria-label="Main navigation">
          {groups.map((group) => (
            <div className="nav-group" key={group.label}>
              <p className="nav-group-label">{group.label}</p>
              {group.items.map((item) => (
                <div
                  key={item.key}
                  className={`sidebar-link${activeTab === item.key ? ' is-active' : ''}`}
                  style={{ pointerEvents: 'none' }}
                >
                  <Icon name={item.icon}/><span>{item.label}</span>
                </div>
              ))}
            </div>
          ))}
        </nav>
        <div className="sidebar-footer"><span className="sidebar-footer-mark" /> Career360 operations</div>
      </aside>

      <div className="admin-workspace">
        <header className="workspace-topbar">
          <div className="topbar-start">
            <span className="topbar-context">Career360 <span>/</span> {copy[activeTab]?.title || 'Overview'}</span>
          </div>
          <div className="topbar-account" style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <span className="skeleton-bone" style={{ width: '29px', height: '29px', borderRadius: '50%' }} />
            <span className="skeleton-bone" style={{ width: '130px', height: '14px', borderRadius: '4px' }} />
          </div>
        </header>

        <main className="workspace-main" id="main-content">
          <div className="page-heading">
            <div>
              <p className="page-kicker">ADMIN WORKSPACE</p>
              <h1>{copy[activeTab]?.title || 'Overview'}</h1>
              <p>{copy[activeTab]?.description || 'A clear view of what needs attention across Career360.'}</p>
            </div>
          </div>

          {activeTab === 'overview' && (
            <div className="overview-content" aria-busy="true">
              <div className="overview-section-heading">
                <div>
                  <h2>Platform at a glance</h2>
                  <p>Current activity and work that needs a decision.</p>
                </div>
              </div>
              <div className="metric-grid">
                {['Awaiting review', 'Active employers', 'Live jobs', 'Job seekers'].map((label) => (
                  <div className="metric-card" key={label} style={{ pointerEvents: 'none' }}>
                    <span className="metric-label">{label}</span>
                    <span className="skeleton-bone skeleton-metric-val" />
                    <span className="metric-bottom">
                      <span className="skeleton-bone" style={{ width: '90px', height: '10px' }} />
                      <span aria-hidden="true">↗</span>
                    </span>
                  </div>
                ))}
              </div>
              <div className="overview-columns">
                <section className="work-panel">
                  <div className="work-panel-heading">
                    <div><p className="section-eyebrow">PRIORITY</p><h2>Needs attention</h2></div>
                    <span className="skeleton-bone" style={{ width: '25px', height: '25px', borderRadius: '5px' }} />
                  </div>
                  <div className="queue-list">
                    {[1, 2, 3].map((i) => (
                      <div key={i} className="queue-row" style={{ pointerEvents: 'none' }}>
                        <span className="skeleton-bone" style={{ width: '8px', height: '8px', borderRadius: '50%', flexShrink: 0 }} />
                        <div className="queue-text" style={{ flex: 1, padding: '0 4px' }}>
                          <span className="skeleton-bone" style={{ width: `${58 - i * 6}%`, height: '14px', marginBottom: '6px' }} />
                          <span className="skeleton-bone" style={{ width: '40%', height: '11px' }} />
                        </div>
                        <span className="skeleton-bone" style={{ width: '56px', height: '18px', borderRadius: '4px' }} />
                      </div>
                    ))}
                  </div>
                </section>
                <section className="work-panel snapshot-panel">
                  <div className="work-panel-heading">
                    <div><p className="section-eyebrow">ACTIVITY</p><h2>Platform snapshot</h2></div>
                  </div>
                  <div className="snapshot-line"><span>Applications recorded</span><span className="skeleton-bone" style={{ width: '38px', height: '18px' }} /></div>
                  <div className="snapshot-line"><span>Closed listings</span><span className="skeleton-bone" style={{ width: '38px', height: '18px' }} /></div>
                  <div className="snapshot-line"><span>Rejected or suspended employers</span><span className="skeleton-bone" style={{ width: '38px', height: '18px' }} /></div>
                </section>
              </div>
            </div>
          )}

          {activeTab === 'employers' && (
            <div className="company-cards-grid" aria-busy="true">
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
                    <div className="detail-item full-width">
                      <span className="skeleton-bone" style={{ width: '60px', height: '10px', marginBottom: '8px' }} />
                      <span className="skeleton-bone" style={{ width: '85%', height: '15px' }} />
                    </div>
                  </div>
                  <div className="company-card-actions" style={{ display: 'flex', gap: '8px', paddingTop: '12px', borderTop: '1px solid #f0f3f6' }}>
                    <span className="skeleton-bone" style={{ width: '120px', height: '36px', borderRadius: '6px' }} />
                  </div>
                </div>
              ))}
            </div>
          )}

          {activeTab === 'plans' && (
            <div className="plans-cards-grid" aria-busy="true">
              {[1, 2, 3].map((i) => (
                <div key={i} className="plan-pricing-card skeleton-card">
                  <div className="plan-card-top">
                    <span className="skeleton-bone" style={{ width: '80px', height: '18px', borderRadius: '4px', marginBottom: '8px' }} />
                    <span className="skeleton-bone" style={{ width: '60%', height: '22px', marginBottom: '6px' }} />
                    <span className="skeleton-bone" style={{ width: '40%', height: '14px' }} />
                  </div>
                  <div className="plan-card-form">
                    <span className="skeleton-bone" style={{ width: '100%', height: '58px', borderRadius: '6px' }} />
                    <span className="skeleton-bone" style={{ width: '100%', height: '58px', borderRadius: '6px' }} />
                    <span className="skeleton-bone" style={{ width: '100%', height: '80px', borderRadius: '6px' }} />
                  </div>
                  <div className="plan-card-actions">
                    <span className="skeleton-bone" style={{ width: '100%', height: '42px', borderRadius: '6px' }} />
                  </div>
                </div>
              ))}
            </div>
          )}

          {activeTab !== 'overview' && activeTab !== 'employers' && activeTab !== 'plans' && (
            <div className="jobs-table-container" aria-busy="true">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>Item</th><th>Category / Detail</th><th>Status</th><th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {[1, 2, 3, 4, 5].map((i) => (
                    <tr key={i} className="skeleton-table-row">
                      <td>
                        <span className="skeleton-bone" style={{ width: `${60 - (i % 3) * 10}%`, height: '15px', marginBottom: '6px' }} />
                        <span className="skeleton-bone" style={{ width: '40%', height: '12px' }} />
                      </td>
                      <td><span className="skeleton-bone" style={{ width: '50%', height: '14px' }} /></td>
                      <td><span className="skeleton-bone" style={{ width: '48px', height: '22px', borderRadius: '4px' }} /></td>
                      <td><span className="skeleton-bone" style={{ width: '80px', height: '30px', borderRadius: '6px' }} /></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </main>
      </div>
    </div>
  );
}
