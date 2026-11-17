import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react';
import { ApiError, getAdminIdentity, type AdminIdentity } from './api';
import { supabase } from './supabase';
import StatsOverview from './StatsOverview';
import EmployersPanel from './EmployersPanel';
import JobsPanel from './JobsPanel';
import PlansPanel from './PlansPanel';
import OperationsPanels from './OperationsPanels';

type View =
  | { kind: 'configuration' }
  | { kind: 'checking' }
  | { kind: 'signedOut' }
  | { kind: 'authorized'; identity: AdminIdentity }
  | { kind: 'denied' }
  | { kind: 'unavailable' };

type ActiveTab = 'overview' | 'users' | 'employers' | 'jobs' | 'plans' | 'payments' | 'content' | 'reports';

function Brand({ light = false }: { light?: boolean }) {
  return (
    <div className={`brand${light ? ' brand-light' : ''}`}>
      <img src="/career360-icon.png" alt="Career360" className="brand-logo-img" />
      <span>Career<span className="brand-number">360</span><span className="brand-admin">Operations</span></span>
    </div>
  );
}

export default function App() {
  const [view, setView] = useState<View>({ kind: 'checking' });
  const [activeTab, setActiveTab] = useState<ActiveTab>('overview');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState('');
  const requestSequence = useRef(0);

  const checkAccess = useCallback(async (token: string) => {
    const currentRequest = ++requestSequence.current;
    setView({ kind: 'checking' });
    try {
      const identity = await getAdminIdentity(token);
      if (currentRequest === requestSequence.current) {
        setView({ kind: 'authorized', identity });
      }
    } catch (error) {
      if (currentRequest !== requestSequence.current) return;
      if (error instanceof ApiError && error.status === 403) {
        setView({ kind: 'denied' });
      } else if (error instanceof ApiError && error.status === 401) {
        setFormError('Your session has expired. Sign in again.');
        try { await supabase.auth.signOut(); } catch { setView({ kind: 'unavailable' }); }
      } else {
        setView({ kind: 'unavailable' });
      }
    }
  }, []);

  useEffect(() => {
    let active = true;
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (!active) return;
      if (session?.access_token) {
        void checkAccess(session.access_token);
      } else {
        setView({ kind: 'signedOut' });
      }
    }).catch(() => {
      if (active) setView({ kind: 'unavailable' });
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (!active) return;
      if (session?.access_token) {
        void checkAccess(session.access_token);
      } else {
        ++requestSequence.current;
        setView({ kind: 'signedOut' });
      }
    });

    return () => {
      active = false;
      ++requestSequence.current;
      subscription.unsubscribe();
    };
  }, [checkAccess]);

  useEffect(() => {
    if (view.kind === 'authorized') {
      window.history.replaceState(null, '', '/dashboard');
    } else if (view.kind === 'signedOut' || view.kind === 'denied') {
      window.history.replaceState(null, '', '/login');
    }
  }, [view.kind]);

  async function handleSignIn(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (submitting) return;
    setFormError('');
    setSubmitting(true);
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password,
      });
      if (error) throw error;
      setPassword('');
      if (data.session?.access_token) {
        await checkAccess(data.session.access_token);
      }
    } catch (error) {
      setFormError((error as { message?: string }).message || 'Email or password is incorrect.');
    } finally {
      setSubmitting(false);
    }
  }

  async function handleSignOut() {
    ++requestSequence.current;
    setFormError('');
    setView({ kind: 'checking' });
    try {
      await supabase.auth.signOut();
    } finally {
      setView({ kind: 'signedOut' });
    }
  }

  if (view.kind === 'authorized') {
    return (
      <div className="dashboard-page">
        <header className="dashboard-header">
          <Brand />
          <nav className="dashboard-nav" aria-label="Main Navigation">
            <button
              className={`nav-tab ${activeTab === 'overview' ? 'active' : ''}`}
              onClick={() => setActiveTab('overview')}
            >
              Overview
            </button>
            <button
              className={`nav-tab ${activeTab === 'employers' ? 'active' : ''}`}
              onClick={() => setActiveTab('employers')}
            >
              Employers
            </button>
            <button
              className={`nav-tab ${activeTab === 'jobs' ? 'active' : ''}`}
              onClick={() => setActiveTab('jobs')}
            >
              Jobs
            </button>
            <button
              className={`nav-tab ${activeTab === 'plans' ? 'active' : ''}`}
              onClick={() => setActiveTab('plans')}
            >
              Plans
            </button>
            <button
              className={`nav-tab ${activeTab === 'users' ? 'active' : ''}`}
              onClick={() => setActiveTab('users')}
            >
              Users
            </button>
            <button
              className={`nav-tab ${activeTab === 'payments' ? 'active' : ''}`}
              onClick={() => setActiveTab('payments')}
            >
              Payments
            </button>
            <button
              className={`nav-tab ${activeTab === 'content' ? 'active' : ''}`}
              onClick={() => setActiveTab('content')}
            >
              Content
            </button>
            <button
              className={`nav-tab ${activeTab === 'reports' ? 'active' : ''}`}
              onClick={() => setActiveTab('reports')}
            >
              Reports
            </button>
          </nav>
          <div className="dashboard-user">
            <span className="user-email">{view.identity.email}</span>
            <button className="signout-button" onClick={() => void handleSignOut()}>Sign out</button>
          </div>
        </header>

        <main className="dashboard-main">
          {activeTab === 'overview' && <StatsOverview onNavigateTab={(tab) => setActiveTab(tab)} />}
          {activeTab === 'employers' && <EmployersPanel />}
          {activeTab === 'jobs' && <JobsPanel />}
          {activeTab === 'plans' && <PlansPanel />}
          {['users', 'payments', 'content', 'reports'].includes(activeTab) && (
            <OperationsPanels kind={activeTab as 'users' | 'payments' | 'content' | 'reports'} />
          )}
        </main>
      </div>
    );
  }

  if (view.kind === 'checking') {
    return (
      <div className="auth-splash">
        <Brand />
        <div className="spinner" />
        <p>Verifying credentials…</p>
      </div>
    );
  }

  if (view.kind === 'denied') {
    return (
      <div className="auth-splash">
        <Brand />
        <div className="error-card">
          <h2>Access restricted</h2>
          <p>This account does not have administrator privileges.</p>
          <button className="primary-button" onClick={() => void handleSignOut()}>Sign in with another account</button>
        </div>
      </div>
    );
  }

  return (
    <div className="login-page-wrapper">
      <header className="login-top-header">
        <Brand />
      </header>

      <main className="login-main-content">
        <section className="login-content" aria-labelledby="login-title">
          <div className="login-heading-block">
            <h1 id="login-title">Sign in to Operations</h1>
            <p>Use your Career360 staff account to continue.</p>
          </div>

          <form className="admin-sign-form" onSubmit={(event) => void handleSignIn(event)} aria-busy={submitting}>
            <div className="form-field-group">
              <label className="field-title" htmlFor="admin-email">Email address</label>
              <input
                id="admin-email"
                className="modern-input"
                type="email"
                autoComplete="username"
                required
                value={email}
                onChange={(event) => setEmail(event.target.value)}
              />
            </div>

            <div className="form-field-group">
              <label className="field-title" htmlFor="admin-password">Password</label>
              <div className="input-with-eye">
                <input
                  id="admin-password"
                  className="modern-input"
                  type={showPassword ? 'text' : 'password'}
                  autoComplete="current-password"
                  required
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                />
                <button
                  type="button"
                  className="eye-toggle-btn"
                  onClick={() => setShowPassword((visible) => !visible)}
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                  aria-pressed={showPassword}
                >
                  {showPassword ? (
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24" /><line x1="1" y1="1" x2="23" y2="23" /></svg>
                  ) : (
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" /><circle cx="12" cy="12" r="3" /></svg>
                  )}
                </button>
              </div>
            </div>

            {formError && <p className="form-error-banner" role="alert">{formError}</p>}

            <button className="sign-in-btn" type="submit" disabled={submitting}>
              {submitting ? 'Signing in?' : 'Sign in'}
            </button>
          </form>

          <p className="login-help">Need access or help with your password? Contact your Career360 administrator.</p>
        </section>
      </main>

    </div>

  );
}
