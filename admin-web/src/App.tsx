import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react';
import { browserSessionPersistence, onIdTokenChanged, setPersistence, signInWithEmailAndPassword, signOut, type User } from 'firebase/auth';
import { ApiError, getAdminIdentity, type AdminIdentity } from './api';
import { auth } from './firebase';
import StatsOverview from './StatsOverview';
import EmployersPanel from './EmployersPanel';
import JobsPanel from './JobsPanel';
import PlansPanel from './PlansPanel';

type View =
  | { kind: 'configuration' }
  | { kind: 'checking' }
  | { kind: 'signedOut' }
  | { kind: 'authorized'; identity: AdminIdentity }
  | { kind: 'denied' }
  | { kind: 'unavailable' };

type ActiveTab = 'overview' | 'employers' | 'jobs' | 'plans';

function Brand({ light = false }: { light?: boolean }) {
  return (
    <div className={`brand${light ? ' brand-light' : ''}`}>
      <span className="brand-logo-circle">360</span>
      <span>Career<span className="brand-number">360</span><span className="brand-admin">Operations</span></span>
    </div>
  );
}

function loginMessage(code: string): string {
  if (['auth/invalid-credential', 'auth/invalid-email', 'auth/wrong-password', 'auth/user-not-found'].includes(code)) {
    return 'Email or password is incorrect.';
  }
  if (code === 'auth/too-many-requests') return 'Too many attempts. Please try again later.';
  if (code === 'auth/network-request-failed') return 'Check your connection and try again.';
  if (code === 'auth/operation-not-allowed') return 'Email/password sign-in is disabled for this Firebase project.';
  if (code === 'auth/invalid-api-key' || code === 'auth/app-not-authorized') return 'Firebase web configuration needs review.';
  return 'Sign in could not be completed. Please try again.';
}

export default function App() {
  const [view, setView] = useState<View>(auth ? { kind: 'checking' } : { kind: 'configuration' });
  const [activeTab, setActiveTab] = useState<ActiveTab>('overview');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState('');
  const requestSequence = useRef(0);

  const checkAccess = useCallback(async (user: User) => {
    const currentRequest = ++requestSequence.current;
    setView({ kind: 'checking' });
    try {
      const identity = await getAdminIdentity(await user.getIdToken());
      if (currentRequest === requestSequence.current) {
        setView({ kind: 'authorized', identity });
      }
    } catch (error) {
      if (currentRequest !== requestSequence.current) return;
      if (error instanceof ApiError && error.status === 403) {
        setView({ kind: 'denied' });
      } else if (error instanceof ApiError && error.status === 401 && auth) {
        setFormError('Your session has expired. Sign in again.');
        try { await signOut(auth); } catch { setView({ kind: 'unavailable' }); }
      } else {
        setView({ kind: 'unavailable' });
      }
    }
  }, []);

  useEffect(() => {
    const adminAuth = auth;
    if (!adminAuth) return;
    let active = true;
    let unsubscribe: (() => void) | undefined;
    void setPersistence(adminAuth, browserSessionPersistence).then(() => {
      if (!active) return;
      unsubscribe = onIdTokenChanged(adminAuth, (user) => {
        if (user) {
          void checkAccess(user);
        } else {
          ++requestSequence.current;
          setView({ kind: 'signedOut' });
        }
      }, () => setView({ kind: 'unavailable' }));
    }).catch(() => { if (active) setView({ kind: 'unavailable' }); });
    return () => {
      active = false;
      ++requestSequence.current;
      unsubscribe?.();
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
    if (!auth || submitting) return;
    setFormError('');
    setSubmitting(true);
    try {
      await signInWithEmailAndPassword(auth, email.trim(), password);
      setPassword('');
    } catch (error) {
      setFormError(loginMessage((error as { code?: string }).code ?? ''));
    } finally {
      setSubmitting(false);
    }
  }

  async function handleSignOut() {
    if (!auth) return;
    ++requestSequence.current;
    setFormError('');
    setView({ kind: 'checking' });
    try {
      await signOut(auth);
    } catch {
      setView({ kind: 'unavailable' });
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
              📊 Overview
            </button>
            <button
              className={`nav-tab ${activeTab === 'employers' ? 'active' : ''}`}
              onClick={() => setActiveTab('employers')}
            >
              🏢 Companies
            </button>
            <button
              className={`nav-tab ${activeTab === 'jobs' ? 'active' : ''}`}
              onClick={() => setActiveTab('jobs')}
            >
              💼 Live Jobs
            </button>
            <button
              className={`nav-tab ${activeTab === 'plans' ? 'active' : ''}`}
              onClick={() => setActiveTab('plans')}
            >
              💳 Pricing & Plans
            </button>
          </nav>
          <div className="account-actions">
            <span className="account-email" title={view.identity.email}>{view.identity.email}</span>
            <button className="text-button" onClick={() => void handleSignOut()}>Sign out</button>
          </div>
        </header>

        <main className="dashboard-main">
          {activeTab === 'overview' && (
            <>
              <div className="tab-header">
                <div>
                  <p className="eyebrow">Platform Intelligence</p>
                  <h1>Operations Overview</h1>
                </div>
              </div>
              <StatsOverview onNavigateTab={(tab) => setActiveTab(tab)} />
            </>
          )}

          {activeTab === 'employers' && (
            <>
              <div className="tab-header">
                <div>
                  <p className="eyebrow">Directory & Moderation</p>
                  <h1>Registered Companies</h1>
                </div>
              </div>
              <EmployersPanel />
            </>
          )}

          {activeTab === 'jobs' && (
            <>
              <div className="tab-header">
                <div>
                  <p className="eyebrow">Quality & Moderation</p>
                  <h1>Active Live Jobs</h1>
                </div>
              </div>
              <JobsPanel />
            </>
          )}

          {activeTab === 'plans' && (
            <>
              <div className="tab-header">
                <div>
                  <p className="eyebrow">Monetization & Catalog</p>
                  <h1>Posting Plans & Pricing</h1>
                </div>
              </div>
              <PlansPanel />
            </>
          )}
        </main>
      </div>
    );
  }

  return (
    <div className="login-page">
      <aside className="login-intro" aria-label="Career360 administration">
        <Brand light />
        <div className="intro-copy">
          <p className="intro-kicker">SUPER ADMIN ACCESS</p>
          <h1>A clear space to manage Career360.</h1>
          <p>Verify employers, grant free starter plans, and oversee direct contact hiring across Tamil Nadu.</p>
        </div>
        <p className="intro-footnote">Career360 Operations Portal</p>
      </aside>
      <main className="login-main">
        <div className="mobile-brand"><Brand /></div>
        <section className="login-content" aria-labelledby="login-title">
          <p className="eyebrow">WELCOME BACK</p>
          <h1 id="login-title">Sign in to admin</h1>
          <p className="login-subtitle">Enter your Career360 super admin email and password.</p>

          <form className="login-form" onSubmit={(e) => void handleSignIn(e)}>
            <label className="field-label" htmlFor="admin-email">Email</label>
            <input
              id="admin-email"
              type="email"
              autoComplete="username"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />

            <div className="password-header">
              <label className="field-label" htmlFor="admin-password">Password</label>
              <button
                type="button"
                className="text-button"
                onClick={() => setShowPassword(!showPassword)}
              >
                {showPassword ? 'Hide' : 'Show'}
              </button>
            </div>
            <input
              id="admin-password"
              type={showPassword ? 'text' : 'password'}
              autoComplete="current-password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />

            {formError && <p className="error-message" role="alert">{formError}</p>}

            <button className="primary-button" type="submit" disabled={submitting}>
              {submitting ? 'Signing in…' : 'Sign in'}
            </button>
          </form>
          <p className="login-footer-note">Access is strictly limited to authorized Career360 staff.</p>
        </section>
      </main>
    </div>
  );
}
