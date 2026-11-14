import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { signOut } from 'firebase/auth';
import { ApiError, archivePlan, listPlans, publishPlan, savePlan, seedPlans, type PlanDraft, type PlanEntry } from './api';
import { auth } from './firebase';

const money = (paise: number) => new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR' }).format(paise / 100);

function totals(draft: PlanDraft) {
  const base = draft.taxMode === 'inclusive'
    ? Math.round(draft.pricePaise * 10000 / (10000 + draft.taxRateBps)) : draft.pricePaise;
  const tax = draft.taxMode === 'inclusive' ? draft.pricePaise - base
    : Math.round(draft.pricePaise * draft.taxRateBps / 10000);
  return { base, tax, total: base + tax };
}

export default function PlansPanel() {
  const [plans, setPlans] = useState<PlanEntry[]>([]);
  const [selected, setSelected] = useState('');
  const [draft, setDraft] = useState<PlanDraft | null>(null);
  const [features, setFeatures] = useState('');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  const token = async () => {
    if (!auth?.currentUser) throw new Error('Sign in again to continue.');
    return auth.currentUser.getIdToken();
  };
  const showError = async (caught: unknown) => {
    if (caught instanceof ApiError && (caught.status === 401 || caught.status === 403) && auth) {
      await signOut(auth).catch(() => setError('Your session has expired. Reload and sign in again.'));
      return;
    }
    setError((caught as Error).message);
  };
  const refresh = useCallback(async () => {
    try {
      const result = await listPlans(await token());
      setPlans(result.plans);
      setSelected((current) => current || result.plans[0]?.id || '');
      setError('');
    } catch (caught) { await showError(caught); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { void refresh(); }, [refresh]);
  useEffect(() => {
    const entry = plans.find((plan) => plan.id === selected);
    setDraft(entry?.draft || null);
    setFeatures((entry?.draft?.features || []).join('\n'));
  }, [plans, selected]);

  const act = async (work: () => Promise<void>, success: string) => {
    setBusy(true); setError(''); setNotice('');
    try { await work(); setNotice(success); await refresh(); }
    catch (caught) { await showError(caught); }
    finally { setBusy(false); }
  };
  const change = <K extends keyof PlanDraft>(key: K, value: PlanDraft[K]) =>
    setDraft((previous) => previous ? { ...previous, [key]: value } : previous);
  const number = (key: keyof PlanDraft, label: string, step = 1) =>
    <label className="plan-field">{label}<input type="number" min="0" step={step} required
      value={draft?.[key] as number ?? 0}
      onChange={(event) => change(key, Number(event.target.value) as never)} /></label>;
  const entry = plans.find((plan) => plan.id === selected);
  const price = draft ? totals(draft) : null;

  return <section className="plans-workspace" aria-labelledby="plans-title">
    <div className="plans-heading">
      <div><p className="eyebrow">EMPLOYER COMMERCE</p><h2 id="plans-title">Hiring plans</h2>
        <p>Draft changes stay private until you publish. Existing orders keep their original price and benefits.</p></div>
      <button className="text-button" disabled={busy} onClick={() => void refresh()}>Refresh</button>
    </div>
    {error && <p className="plan-alert plan-error" role="alert">{error}</p>}
    {notice && <p className="plan-alert" role="status">{notice}</p>}
    {loading ? <p>Loading plans…</p> : plans.length === 0 ? <div className="plan-empty">
      <h3>Prepare the first catalog</h3>
      <p>This creates four editable drafts. Check the prices and GST settings before publishing each plan.</p>
      <button className="primary-button" disabled={busy} onClick={() => void act(async () => { await seedPlans(await token()); }, 'Drafts created.')}>Create starter drafts</button>
    </div> : <div className="plans-grid">
      <nav className="plan-list" aria-label="Plans">
        {plans.map((plan) => <button key={plan.id} type="button" className={`plan-list-item${selected === plan.id ? ' selected' : ''}`}
          onClick={() => setSelected(plan.id)}>
          <span><strong>{plan.draft?.name || plan.id}</strong><small>{plan.id}</small></span>
          <span className={plan.published ? 'live-pill' : 'draft-pill'}>{plan.published ? `Live v${plan.version}` : 'Draft'}</span>
        </button>)}
      </nav>
      {draft && <form className="plan-editor" onSubmit={(event: FormEvent) => { event.preventDefault();
        void act(async () => { await savePlan(await token(), selected, { ...draft,
          features: features.split('\n').map((line) => line.trim()).filter(Boolean) }); }, 'Draft saved.'); }}>
        <div className="editor-title"><div><h3>{draft.name}</h3><p>Plan ID: {selected} · Published version: {entry?.version || 0}</p>
          {entry?.published && <p className="live-summary">Live now: {entry.published.priceDisplay} · {entry.published.profileUnlockLimit} profile unlocks · {entry.published.listingDays} days per post</p>}
        </div></div>
        <div className="plan-fields">
          <label className="plan-field">Plan name<input value={draft.name} maxLength={70} required onChange={(event) => change('name', event.target.value)} /></label>
          <label className="plan-field">Badge<input value={draft.badge} maxLength={32} onChange={(event) => change('badge', event.target.value)} /></label>
          <label className="plan-field">Tier<select value={draft.tier} onChange={(event) => change('tier', event.target.value as PlanDraft['tier'])}>
            <option value="free">Free</option><option value="standard">Starter</option><option value="featured">Premium</option><option value="elite">Elite</option></select></label>
          <label className="plan-field">Reach<select value={draft.reach} onChange={(event) => change('reach', event.target.value as PlanDraft['reach'])}>
            <option value="district">One district</option><option value="statewide">Statewide</option></select></label>
          {number('pricePaise', 'Entered price (paise)')}
          <label className="plan-field">GST treatment<select value={draft.taxMode} onChange={(event) => change('taxMode', event.target.value as PlanDraft['taxMode'])}>
            <option value="inclusive">Included in entered price</option><option value="exclusive">Added to entered price</option></select></label>
          {number('taxRateBps', 'GST rate (basis points; 1800 = 18%)')}
          {number('jobCredits', 'Job posts')}
          {number('listingDays', 'Days each job stays live')}
          {number('creditValidityDays', 'Plan term (days)')}
          {number('profileUnlockLimit', 'Applicant profile unlocks')}
          {number('sortOrder', 'Display order')}
        </div>
        <label className="plan-field plan-wide">Benefits, one per line<textarea rows={4} value={features} onChange={(event) => setFeatures(event.target.value)} /></label>
        {price && <div className="price-preview"><span>Price before GST <b>{money(price.base)}</b></span><span>GST <b>{money(price.tax)}</b></span><span>Customer pays <strong>{money(price.total)}</strong></span></div>}
        <div className="editor-actions">
          <button className="primary-button" disabled={busy} type="submit">Save draft</button>
          <button className="secondary-button" disabled={busy} type="button" onClick={() => {
            if (window.confirm('Publish the saved draft to the employer app? Unsaved edits will not be included.'))
              void act(async () => { await publishPlan(await token(), selected); }, 'Plan published.');
          }}>Publish saved draft</button>
          {entry?.published && <button className="text-button archive-action" disabled={busy} type="button" onClick={() => {
            if (window.confirm('Hide this plan from new purchases? Existing orders remain valid.'))
              void act(async () => { await archivePlan(await token(), selected); }, 'Plan archived.');
          }}>Archive plan</button>}
        </div>
      </form>}
    </div>}
  </section>;
}
