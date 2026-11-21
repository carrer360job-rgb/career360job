import { useCallback, useEffect, useState } from 'react';
import { getAccessToken } from './supabase';
import { getAdvertising, saveAdvertising, type AdvertisingSettings as Settings } from './api';

export default function AdvertisingSettings() {
  const [settings, setSettings] = useState<Settings | null>(null);
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const load = useCallback(async () => {
    setLoading(true); setError('');
    try { setSettings(await getAdvertising(await getAccessToken())); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Unable to load settings.'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { void load(); }, [load]);
  return <section className="settings-panel advertising-settings" aria-labelledby="advertising-title">
    <div className="settings-panel-heading">
      <h2 id="advertising-title">Advertising</h2>
      <p>Manage advertising on Android job browsing screens. Changes reach open screens within about a minute.</p>
    </div>
    {loading && <p role="status">Loading advertising settings?</p>}
    {!loading && settings && <form onSubmit={async event => {
      event.preventDefault(); setBusy(true); setError(''); setMessage('');
      try { setSettings(await saveAdvertising(await getAccessToken(), settings)); setMessage('Advertising settings saved.'); }
      catch (cause) { setError(cause instanceof Error ? cause.message : 'Save failed.'); }
      finally { setBusy(false); }
    }}>
      <fieldset disabled={busy} className="advertising-fields">
        {([
          ['enabled', 'Enable advertising', 'Master switch for all ad placements.'],
          ['banner', 'Home banner', 'A separate advertisement beneath the home feed.'],
          ['native', 'Search advertisements', 'Clearly labelled advertisements between job cards.'],
          ['interstitial', 'Full-screen advertisements', 'Only at browsing breaks. Keep off until device testing is complete.'],
        ] as const).map(([key, label, description]) => <label className="advertising-switch" key={key}>
          <span><strong>{label}</strong><small>{description}</small></span>
          <input type="checkbox" checked={settings[key]} onChange={event => { setMessage(''); setSettings({ ...settings, [key]: event.target.checked }); }} />
        </label>)}
        <div className="advertising-limits">
          {([
            ['native_interval', 'Jobs between search ads', 5, 12],
            ['interstitial_views', 'Job views before a full-screen ad', 5, 20],
            ['cooldown_minutes', 'Minutes between full-screen ads', 10, 60],
            ['daily_cap', 'Full-screen ads per day', 1, 2],
          ] as const).map(([key, label, min, max]) => <label className="settings-field" key={key}>
            {label}<input type="number" min={min} max={max} required value={settings[key]} onChange={event => { setMessage(''); setSettings({ ...settings, [key]: Number(event.target.value) }); }} />
            <small>Allowed: {min}?{max}</small>
          </label>)}
        </div>
        <button className="primary-button settings-save" type="submit">{busy ? 'Saving?' : 'Save advertising settings'}</button>
      </fieldset>
      {settings.updated_at && <p className="advertising-updated">Last saved {new Date(settings.updated_at).toLocaleString()}</p>}
    </form>}
    {error && <p className="settings-feedback is-error" role="alert">{error} {!settings && <button type="button" onClick={() => void load()}>Retry</button>}</p>}
    {message && <p className="settings-feedback is-success" role="status">{message}</p>}
  </section>;
}
