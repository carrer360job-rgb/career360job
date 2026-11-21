import AdvertisingSettings from './AdvertisingSettings';
import { useState, type FormEvent } from 'react';
import type { AdminIdentity } from './api';
import { supabase } from './supabase';

type Props = { identity: AdminIdentity };

export default function SettingsPanel({ identity }: Props) {
  const [password, setPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmation, setShowConfirmation] = useState(false);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (saving) return;
    setMessage('');
    setError('');
    if (password.length < 8) {
      setError('Use at least 8 characters for your new password.');
      return;
    }
    if (password !== confirmation) {
      setError('The passwords do not match.');
      return;
    }

    setSaving(true);
    try {
      const { data: userData, error: userError } = await supabase.auth.getUser();
      if (userError || userData.user?.id !== identity.uid) {
        throw new Error('Your admin session has expired. Sign in again before changing your password.');
      }
      const { error: updateError } = await supabase.auth.updateUser({ password });
      if (updateError) throw updateError;
      setPassword('');
      setConfirmation('');
      setMessage('Password saved. Use the new password the next time you sign in.');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not save your password. Try again.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <> <section className="settings-panel" aria-labelledby="settings-password-title">
      <div className="settings-panel-heading">
        <p className="section-eyebrow">ACCOUNT SECURITY</p>
        <h2 id="settings-password-title">Change password</h2>
        <p>Choose a new password for your Career360 admin account.</p>
        <span className="settings-account">{identity.email}</span>
      </div>

      <form className="settings-password-form" onSubmit={(event) => void handleSubmit(event)} aria-busy={saving}>
        <div className="settings-field">
          <label htmlFor="settings-new-password">New password</label>
          <div className="input-with-eye">
            <input
              id="settings-new-password"
              type={showPassword ? 'text' : 'password'}
              autoComplete="new-password"
              minLength={8}
              required
              value={password}
              onChange={(event) => { setPassword(event.target.value); setError(''); setMessage(''); }}
              aria-describedby="settings-password-help"
            />
            <button
              type="button"
              className="eye-toggle-btn"
              onClick={() => setShowPassword((prev) => !prev)}
              aria-label={showPassword ? 'Hide password' : 'Show password'}
              title={showPassword ? 'Hide password' : 'Show password'}
            >
              {showPassword ? (
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24" />
                  <line x1="1" y1="1" x2="23" y2="23" />
                </svg>
              ) : (
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                  <circle cx="12" cy="12" r="3" />
                </svg>
              )}
            </button>
          </div>
          <small id="settings-password-help">Use at least 8 characters.</small>
        </div>
        <div className="settings-field">
          <label htmlFor="settings-confirm-password">Confirm new password</label>
          <div className="input-with-eye">
            <input
              id="settings-confirm-password"
              type={showConfirmation ? 'text' : 'password'}
              autoComplete="new-password"
              minLength={8}
              required
              value={confirmation}
              onChange={(event) => { setConfirmation(event.target.value); setError(''); setMessage(''); }}
            />
            <button
              type="button"
              className="eye-toggle-btn"
              onClick={() => setShowConfirmation((prev) => !prev)}
              aria-label={showConfirmation ? 'Hide password' : 'Show password'}
              title={showConfirmation ? 'Hide password' : 'Show password'}
            >
              {showConfirmation ? (
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24" />
                  <line x1="1" y1="1" x2="23" y2="23" />
                </svg>
              ) : (
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                  <circle cx="12" cy="12" r="3" />
                </svg>
              )}
            </button>
          </div>
        </div>
        {error && <p className="settings-feedback is-error" role="alert">{error}</p>}
        {message && <p className="settings-feedback is-success" role="status">{message}</p>}
        <button className="primary-button settings-save" type="submit" disabled={saving}>
          {saving ? 'Saving…' : 'Save password'}
        </button>
      </form>
    </section><AdvertisingSettings /></>
  );
}
