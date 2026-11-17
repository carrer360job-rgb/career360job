import { useEffect, useRef, useState, type ReactNode } from 'react';
import type { AdminIdentity } from './api';
import './dashboard.css';

export type AdminTab = 'overview' | 'employers' | 'jobs' | 'users' | 'plans' | 'payments' | 'content' | 'reports';

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
    { key: 'users', label: 'People', icon: 'people' },
  ] },
  { label: 'Commerce', items: [
    { key: 'plans', label: 'Hiring plans', icon: 'layers' },
    { key: 'payments', label: 'Payments', icon: 'receipt' },
  ] },
  { label: 'Platform', items: [
    { key: 'content', label: 'Content', icon: 'file' },
    { key: 'reports', label: 'Reports', icon: 'flag' },
  ] },
];

const copy: Record<AdminTab, { title: string; description: string }> = {
  overview: { title: 'Overview', description: 'A clear view of what needs attention across Career360.' },
  employers: { title: 'Employers', description: 'Review companies and manage access to hiring.' },
  jobs: { title: 'Jobs', description: 'Review live listings and take action on unsafe posts.' },
  users: { title: 'People', description: 'Search and manage platform accounts.' },
  plans: { title: 'Hiring plans', description: 'Set the offers employers see in the app.' },
  payments: { title: 'Payments', description: 'Track orders, payment status, and refunds.' },
  content: { title: 'Content', description: 'Maintain categories and announcements.' },
  reports: { title: 'Reports', description: 'Resolve reported listings and review platform totals.' },
};

function Icon({ name, size = 19 }: { name: string; size?: number }) {
  const paths: Record<string, ReactNode> = {
    grid: <><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></>,
    building: <><rect x="4" y="3" width="16" height="18" rx="2"/><path d="M9 21v-4h6v4M8 8h2m4 0h2M8 12h2m4 0h2"/></>,
    briefcase: <><rect x="3" y="7" width="18" height="14" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 13c5 3 13 3 18 0"/></>,
    people: <><circle cx="9" cy="8" r="3"/><path d="M3 20v-2a6 6 0 0 1 12 0v2H3Zm12-14a3 3 0 0 1 0 6m2 3a5 5 0 0 1 4 5h-4"/></>,
    layers: <><rect x="4" y="4" width="16" height="5" rx="1"/><rect x="4" y="11" width="16" height="5" rx="1"/><path d="M4 19h16"/></>,
    receipt: <><path d="M5 3h14v18l-3-2-4 2-4-2-3 2V3Z"/><path d="M9 8h6m-6 4h6"/></>,
    file: <><path d="M6 3h8l4 4v14H6V3Z"/><path d="M14 3v5h4M9 12h6m-6 4h6"/></>,
    flag: <><path d="M5 21V4m0 1c6-4 8 3 15-1v11c-7 4-9-3-15 1"/></>,
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
