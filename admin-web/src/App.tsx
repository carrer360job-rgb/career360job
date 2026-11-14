import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react';
import { onIdTokenChanged, signInWithEmailAndPassword, signOut, type User } from 'firebase/auth';
import { ApiError, getAdminIdentity, type AdminIdentity } from './api';
import { auth, missingConfiguration } from './firebase';

type View =
  | { kind: 'configuration' }
  | { kind: 'checking' }
  | { kind: 'signedOut' }
  | { kind: 'authorized'; identity: AdminIdentity }
  | { kind: 'denied' }
  | { kind: 'unavailable' };

function Brand({ light = false }: { light?: boolean }) {
  return <div className={`brand${light ? ' brand-light' : ''}`}>
    <img src="/career360-icon.png" alt="" width="36" height="36" />
    <span>Career<span className="brand-number">360</span><span className="brand-admin">Admin</span></span>
  </div>;
}

function loginMessage(code: string): string {
  if (['auth/invalid-credential', 'auth/invalid-email', 'auth/wrong-password', 'auth/user-not-found'].includes(code)) {
    return 'Email or password is incorrect.';
  }
  if (code === 'auth/too-many-requests') return 'Too many attempts. Please try again later.';
  if (code === 'auth/network-request-failed') return 'Check your connection and try again.';
  return 'Sign in could not be completed. Please try again.';
}

export default function App() {
  const [view, setView] = useState<View>(auth ? { kind: 'checking' } : { kind: 'configuration' });
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
        await signOut(auth);
      } else {
        setView({ kind: 'unavailable' });
      }
    }
  }, []);

  useEffect(() => {
    if (!auth) return;
    const unsubscribe = onIdTokenChanged(auth, (user) => {
      if (user) {
        void checkAccess(user);
      } else {
        ++requestSequence.current;
        setView({ kind: 'signedOut' });
      }
    }, () => setView({ kind: 'unavailable' }));
    return () => {
      ++requestSequence.current;
      unsubscribe();
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
    setFormError('');
    setView({ kind: 'checking' });
    try {
      await signOut(auth);
    } catch {
      setView({ kind: 'unavailable' });
    }
  }

  if (view.kind === 'authorized') {
    return <div className="dashboard-page">
      <header className="dashboard-header">
        <Brand />
        <div className="account-actions">
          <span className="account-email" title={view.identity.email}>{view.identity.email}</span>
          <button className="text-button" onClick={() => void handleSignOut()}>Sign out</button>
        </div>
      </header>
      <main className="dashboard-main">
        <p className="eyebrow">Administration</p>
        <h1>Dashboard</h1>
        <div className="dashboard-empty" role="status">
          <div className="empty-rule" />
          <h2>Your workspace is ready.</h2>
          <p>Management tools will appear here as they are added.</p>
        </div>
      </main>
    </div>;
  }

  return <div className="login-page">
    <aside className="login-intro" aria-label="Career360 administration">
      <Brand light />
      <div className="intro-copy">
        <p className="intro-kicker">OPERATIONS ACCESS</p>
        <h1>A clear space to manage Career360.</h1>
        <p>Sign in with your authorized admin account.</p>
      </div>
      <p className="intro-footnote">Career360 administration</p>
    </aside>
    <main className="login-main">
      <div className="mobile-brand"><Brand /></div>
      <section className="login-content" aria-labelledby="login-title">
        {view.kind === 'configuration' ? <>
          <p className="eyebrow">SETUP REQUIRED</p>
          <h2 id="login-title">Admin setup is incomplete</h2>
          <p className="supporting-copy">Set the Firebase web app and backend URL values before signing in.</p>
          <p className="setup-hint">Missing: {missingConfiguration.join(', ')}</p>
        </> : view.kind === 'checking' ? <div className="checking" role="status" aria-live="polite">
          <span className="spinner" aria-hidden="true" />
          <p>Checking your access…</p>
        </div> : view.kind === 'denied' ? <>
          <p className="eyebrow">ACCESS RESTRICTED</p>
          <h2 id="login-title">Admin access required</h2>
          <p className="supporting-copy">This account cannot open the admin workspace.</p>
          <button className="primary-button" onClick={() => void handleSignOut()}>Use another account</button>
        </> : view.kind === 'unavailable' ? <>
          <p className="eyebrow">CONNECTION ISSUE</p>
          <h2 id="login-title">Could not check your access</h2>
          <p className="supporting-copy">Check your connection and try again.</p>
          <button className="primary-button" onClick={() => {
            if (auth?.currentUser) void checkAccess(auth.currentUser);
            else setView({ kind: 'signedOut' });
          }}>Try again</button>
          <button className="secondary-button" onClick={() => void handleSignOut()}>Sign out</button>
        </> : <>
          <p className="eyebrow">WELCOME BACK</p>
          <h2 id="login-title">Sign in to admin</h2>
          <p className="supporting-copy">Enter your Career360 admin email and password.</p>
          <form onSubmit={(event) => void handleSignIn(event)}>
            <label htmlFor="email">Email</label>
            <input id="email" name="email" type="email" autoComplete="username" inputMode="email"
              required value={email} onChange={(event) => setEmail(event.target.value)} />
            <label htmlFor="password">Password</label>
            <div className="password-field">
              <input id="password" name="password" type={showPassword ? 'text' : 'password'}
                autoComplete="current-password" required value={password}
                onChange={(event) => setPassword(event.target.value)} />
              <button type="button" className="show-password" aria-label={showPassword ? 'Hide password' : 'Show password'}
                onClick={() => setShowPassword((value) => !value)}>{showPassword ? 'Hide' : 'Show'}</button>
            </div>
            {formError && <p className="form-error" role="alert">{formError}</p>}
            <button className="primary-button" type="submit" disabled={submitting || !email.trim() || !password}>
              {submitting ? 'Signing in…' : 'Sign in'}
            </button>
          </form>
          <p className="access-note">Access is limited to authorized Career360 staff.</p>
        </>}
      </section>
    </main>
  </div>;
}
