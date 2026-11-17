import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react';
import { ApiError, getAdminIdentity, type AdminIdentity } from './api';
import { supabase } from './supabase';
import StatsOverview from './StatsOverview';
import EmployersPanel from './EmployersPanel';
import JobsPanel from './JobsPanel';
import PlansPanel from './PlansPanel';
import OperationsPanels from './OperationsPanels';
import AdminDashboard, { AdminDashboardSkeleton } from './AdminDashboard';

type View =
  | { kind: 'configuration' }
  | { kind: 'checking' }
  | { kind: 'signedOut' }
  | { kind: 'authorized'; identity: AdminIdentity }
  | { kind: 'denied' }
  | { kind: 'unavailable' };

type ActiveTab = 'overview' | 'users' | 'employers' | 'jobs' | 'plans' | 'payments' | 'reports';

function Brand() {
  return (
    <div className="brand">
      <img src="/career360-icon.png" alt="Career360" className="brand-logo-img" />
      <span>Career<span className="brand-number">360</span><span className="brand-admin">Operations</span></span>
    </div>
  );
}

export default function App() {
  const [view, setView] = useState<View>({ kind: 'checking' });
  const [activeTab, setActiveTab] = useState<ActiveTab>(() => {
    try {
      const saved = sessionStorage.getItem('career360_admin_active_tab') as ActiveTab | null;
      if (saved && ['overview', 'employers', 'jobs', 'users', 'plans', 'payments', 'reports'].includes(saved)) {
        return saved;
      }
    } catch { /* ignore */ }
    return 'overview';
  });

  useEffect(() => {
    try {
      sessionStorage.setItem('career360_admin_active_tab', activeTab);
    } catch { /* ignore */ }
  }, [activeTab]);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState('');
  const requestSequence = useRef(0);
  const signingIn = useRef(false);
  const authorizedToken = useRef<string | null>(null);

  const checkAccess = useCallback(async (token: string) => {
    if (authorizedToken.current === token) return;
    const currentRequest = ++requestSequence.current;
    try {
      const identity = await getAdminIdentity(token);
      if (currentRequest === requestSequence.current) {
        authorizedToken.current = token;
        setView({ kind: 'authorized', identity });
      }
    } catch (error) {
      if (currentRequest !== requestSequence.current) return;
      if (error instanceof ApiError && error.status === 403) {
        authorizedToken.current = null;
        setView({ kind: 'denied' });
      } else if (error instanceof ApiError && error.status === 401) {
        authorizedToken.current = null;
        setFormError('Your session has expired. Sign in again.');
        try {
          const { error: signOutError } = await supabase.auth.signOut();
          if (signOutError) throw signOutError;
        } catch { setView({ kind: 'unavailable' }); }
      } else {
        setView({ kind: 'unavailable' });
      }
    }
  }, []);

  useEffect(() => {
    let active = true;
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (!active || signingIn.current) return;
      if (session?.access_token) {
        void checkAccess(session.access_token);
      } else {
        ++requestSequence.current;
        authorizedToken.current = null;
        setView({ kind: 'signedOut' });
      }
    });

    return () => {
      active = false;
      ++requestSequence.current;
      authorizedToken.current = null;
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
    signingIn.current = true;
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
      } else {
        throw new Error('Sign in did not create a session. Try again.');
      }
    } catch (error) {
      setFormError((error as { message?: string }).message || 'Email or password is incorrect.');
    } finally {
      signingIn.current = false;
      setSubmitting(false);
    }
  }

  async function handleSignOut() {
    ++requestSequence.current;
    authorizedToken.current = null;
    setFormError('');
    setView({ kind: 'checking' });
    try {
      const { error } = await supabase.auth.signOut();
      if (error) throw error;
      setView({ kind: 'signedOut' });
    } catch {
      setView({ kind: 'unavailable' });
    }
  }

  async function retryAccess() {
    setView({ kind: 'checking' });
    try {
      const { data, error } = await supabase.auth.getSession();
      if (error) throw error;
      if (data.session?.access_token) {
        await checkAccess(data.session.access_token);
      } else {
        setView({ kind: 'signedOut' });
      }
    } catch {
      setView({ kind: 'unavailable' });
    }
  }

  if (view.kind === 'authorized') {
    return (
      <AdminDashboard identity={view.identity} activeTab={activeTab} onTabChange={setActiveTab} onSignOut={() => void handleSignOut()}>
          {activeTab === 'overview' && <StatsOverview onNavigateTab={(tab) => setActiveTab(tab)} />}
          {activeTab === 'employers' && <EmployersPanel />}
          {activeTab === 'jobs' && <JobsPanel />}
          {activeTab === 'plans' && <PlansPanel />}
          {['users', 'payments', 'reports'].includes(activeTab) && (
            <OperationsPanels key={activeTab} kind={activeTab as 'users' | 'payments' | 'reports'} />
          )}
      </AdminDashboard>
    );
  }

  if (view.kind === 'checking') {
    if (window.location.pathname === '/login') {
      return (
        <div className="auth-splash">
          <Brand />
          <div className="spinner" />
          <p>Verifying session...</p>
        </div>
      );
    }
    return <AdminDashboardSkeleton activeTab={activeTab} />;
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

  if (view.kind === 'unavailable') {
    return (
      <div className="login-page-wrapper">
        <header className="login-top-header"><Brand /></header>
        <main className="login-main-content">
          <section className="login-content" aria-labelledby="unavailable-title">
            <div className="login-heading-block">
              <h1 id="unavailable-title">Unable to open Operations</h1>
              <p>We could not verify your admin access right now. Check your connection and try again.</p>
            </div>
            <button className="sign-in-btn" type="button" onClick={() => void retryAccess()}>Try again</button>
          </section>
        </main>
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
              {submitting ? 'Signing in...' : 'Sign in'}
            </button>
          </form>

          <p className="login-help">Need access or help with your password? Contact your Career360 administrator.</p>
        </section>
      </main>

    </div>

  );
}
