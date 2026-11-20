import { useCallback, useEffect, useRef, useState } from 'react';
import { ApiError, archivePlan, listPlans, publishPlan, savePlan, seedPlans, type PlanDraft, type PlanEntry } from './api';
import { auth } from './supabase';

const money = (paise: number) =>
  new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(paise / 100);

function totals(draft: PlanDraft) {
  const base = draft.taxMode === 'inclusive'
    ? Math.round(draft.pricePaise * 10000 / (10000 + draft.taxRateBps)) : draft.pricePaise;
  const tax = draft.taxMode === 'inclusive' ? draft.pricePaise - base
    : Math.round(draft.pricePaise * draft.taxRateBps / 10000);
  return { base, tax, total: base + tax };
}

export default function PlansPanel() {
  const [plans, setPlans] = useState<PlanEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const requestId = useRef(0);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  const token = async () => {
    if (!auth?.currentUser) throw new Error('Sign in again to continue.');
    return auth.currentUser.getIdToken();
  };

  const showError = async (caught: unknown) => {
    if (caught instanceof ApiError && (caught.status === 401 || caught.status === 403) && auth) {
      await auth.signOut().catch(() => setError('Your session has expired. Reload and sign in again.'));
      return;
    }
    setError((caught as Error).message);
  };

  const refresh = useCallback(async () => {
    const currentRequest = ++requestId.current;
    setRefreshing(true);
    try {
      const result = await listPlans(await token());
      if (currentRequest !== requestId.current) return;
      setPlans(result.plans);
      setError('');
    } catch (caught) {
      if (currentRequest === requestId.current) await showError(caught);
    } finally {
      if (currentRequest === requestId.current) {
        setLoading(false);
        setRefreshing(false);
      }
    }
  }, []);

  useEffect(() => {
    const timer = setTimeout(() => { void refresh(); }, 0);
    return () => { clearTimeout(timer); ++requestId.current; };
  }, [refresh]);

  const handleUpdateAndPublish = async (id: string, draft: PlanDraft) => {
    setBusy(true); setError(''); setNotice('');
    try {
      const tok = await token();
      await savePlan(tok, id, draft);
      await publishPlan(tok, id);
      setNotice(`Updated and published ${draft.name} (${money(draft.pricePaise)}) to the mobile app!`);
      await refresh();
    } catch (caught) {
      await showError(caught);
    } finally {
      setBusy(false);
    }
  };

  const handleArchive = async (id: string) => {
    if (!window.confirm('Hide this plan from new purchases in the app? Existing employer orders remain valid.')) return;
    setBusy(true); setError(''); setNotice('');
    try {
      const tok = await token();
      await archivePlan(tok, id);
      setNotice('Plan archived.');
      await refresh();
    } catch (caught) {
      await showError(caught);
    } finally {
      setBusy(false);
    }
  };

  return (
    <section className="plans-workspace" aria-labelledby="plans-title">
      <div className="plans-heading">
        <div>
          <h2 id="plans-title">Hiring Plans & Pricing</h2>
          <p>Configure package prices, GST options, and promotional badges displayed to employers in the Career360 mobile app.</p>
        </div>
        <button className="text-button" disabled={busy || refreshing} onClick={() => void refresh()}>
          {refreshing ? 'Refreshing...' : 'Refresh'}
        </button>
      </div>

      {error && <p className="plan-alert plan-error" role="alert">{error}</p>}
      {notice && <p className="plan-alert" role="status">{notice}</p>}

      {loading ? (
        <div className="plans-cards-grid" aria-busy="true" aria-label="Loading plans">
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
      ) : plans.length === 0 ? (
        <div className="plan-empty">
          <h3>No hiring plans initialized</h3>
          <p>Create the Monthly, Quarterly, and Yearly subscription plans.</p>
          <button
            className="primary-button"
            disabled={busy}
            onClick={async () => {
              setBusy(true);
              try {
                await seedPlans(await token());
                setNotice('Initial plan catalog created.');
                await refresh();
              } catch (e) {
                await showError(e);
              } finally {
                setBusy(false);
              }
            }}
          >
            Initialize Subscription Plans
          </button>
        </div>
      ) : (
        <div className="plans-cards-grid">
          {plans.map((entry) => (
            <PlanPricingCard
              key={entry.id}
              entry={entry}
              busy={busy}
              onSaveAndPublish={handleUpdateAndPublish}
              onArchive={handleArchive}
            />
          ))}
        </div>
      )}
    </section>
  );
}

function PlanPricingCard({
  entry,
  busy,
  onSaveAndPublish,
  onArchive,
}: {
  entry: PlanEntry;
  busy: boolean;
  onSaveAndPublish: (id: string, draft: PlanDraft) => Promise<void>;
  onArchive: (id: string) => Promise<void>;
}) {
  const current = entry.draft || entry.published;
  const initialRupees = current ? Math.round(current.pricePaise / 100) : 0;
  const initialTaxBps = current?.taxRateBps ?? 1800;

  const [priceRupees, setPriceRupees] = useState<string>(String(initialRupees));
  const [taxMode, setTaxMode] = useState<PlanDraft['taxMode']>(current?.taxMode || 'inclusive');
  const [isGstEnabled, setIsGstEnabled] = useState<boolean>(initialTaxBps > 0);
  const [gstPercent, setGstPercent] = useState<string>(initialTaxBps > 0 ? String(initialTaxBps / 100) : '18');
  const [badge, setBadge] = useState<string>(current?.badge || '');
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [jobCredits, setJobCredits] = useState<number>(current?.jobCredits ?? 1);
  const [listingDays, setListingDays] = useState<number>(current?.listingDays ?? 15);
  const [durationDays, setDurationDays] = useState<number>(current?.creditValidityDays ?? 30);
  const [profileUnlockLimit, setProfileUnlockLimit] = useState<number>(current?.profileUnlockLimit ?? 25);
  const [features, setFeatures] = useState<string[]>(current?.features || []);
  const [newBenefit, setNewBenefit] = useState<string>('');
  const [cardBusy, setCardBusy] = useState(false);

  useEffect(() => {
    const src = entry.draft || entry.published;
    if (src) {
      setPriceRupees(String(Math.round(src.pricePaise / 100)));
      setTaxMode(src.taxMode);
      const bps = src.taxRateBps ?? 1800;
      setIsGstEnabled(bps > 0);
      setGstPercent(bps > 0 ? String(bps / 100) : '18');
      setBadge(src.badge || '');
      setJobCredits(src.jobCredits);
      setListingDays(src.listingDays);
      setDurationDays(src.creditValidityDays);
      setProfileUnlockLimit(src.profileUnlockLimit);
      setFeatures(src.features || []);
    }
  }, [entry]);

  const numPrice = Math.max(0, parseInt(priceRupees, 10) || 0);
  const pricePaise = numPrice * 100;

  const parsedPercent = parseFloat(gstPercent);
  const validPercent = isNaN(parsedPercent) ? 0 : Math.max(0, Math.min(50, parsedPercent));
  const taxRateBps = isGstEnabled ? Math.round(validPercent * 100) : 0;

  const draft: PlanDraft = {
    name: current?.name || entry.id,
    tier: current?.tier || 'monthly',
    badge: badge.trim(),
    pricePaise,
    taxMode: isGstEnabled ? taxMode : 'inclusive',
    taxRateBps,
    jobCredits,
    listingDays,
    creditValidityDays: durationDays,
    profileUnlockLimit,
    reach: current?.reach || 'district',
    sortOrder: current?.sortOrder ?? 0,
    features: features.map((l) => l.trim()).filter(Boolean),
  };

  const priceCalc = totals(draft);
  const isFeatured = current?.tier === 'quarterly';
  const isElite = current?.tier === 'yearly';
  const tierCardClass = isFeatured ? 'tier-featured' : isElite ? 'tier-elite' : 'tier-standard';
  const tierBadgeClass = isFeatured ? 'tier-badge-featured' : isElite ? 'tier-badge-elite' : 'tier-badge-standard';
  const tierTag = isFeatured ? 'Quarterly' : isElite ? 'Yearly' : 'Monthly';
  const isPublished = Boolean(entry.published);

  return (
    <div className={`plan-pricing-card ${tierCardClass}`}>
      <div className="plan-card-top">
        <div className="plan-card-tier-tag">
          <span className={`plan-tier-badge ${tierBadgeClass}`}>{tierTag}</span>
        </div>
        <h3 className="plan-card-title">{current?.name || entry.id}</h3>
        <p className="plan-card-scope">
          {current?.reach === 'statewide' ? 'All Tamil Nadu' : 'One District'} • {jobCredits} Job Post{jobCredits === 1 ? '' : 's'}
        </p>
      </div>

      <div className="plan-card-form">
        <div className="plan-input-group">
          <label htmlFor={`price-${entry.id}`}>Plan Price (in ₹ Rupees)</label>
          <div className="currency-input-wrap">
            <span className="currency-symbol">₹</span>
            <input
              id={`price-${entry.id}`}
              type="number"
              min="0"
              step="1"
              value={priceRupees}
              onChange={(e) => setPriceRupees(e.target.value)}
              placeholder="e.g. 2360"
            />
          </div>
        </div>

        <div className="plan-input-group">
          <label>Goods & Services Tax (GST)</label>
          <div className="gst-toggle-group">
            <button
              type="button"
              className={`gst-toggle-btn ${!isGstEnabled ? 'active' : ''}`}
              onClick={() => setIsGstEnabled(false)}
            >
              No GST (Tax-Free)
            </button>
            <button
              type="button"
              className={`gst-toggle-btn ${isGstEnabled ? 'active' : ''}`}
              onClick={() => {
                setIsGstEnabled(true);
                if (!gstPercent || parseFloat(gstPercent) === 0) setGstPercent('18');
              }}
            >
              Apply GST
            </button>
          </div>
        </div>

        {isGstEnabled && (
          <>
            <div className="plan-input-group">
              <label htmlFor={`tax-rate-${entry.id}`}>GST Percentage (%)</label>
              <div className="percent-input-wrap">
                <input
                  id={`tax-rate-${entry.id}`}
                  type="number"
                  min="0"
                  max="50"
                  step="any"
                  value={gstPercent}
                  onChange={(e) => setGstPercent(e.target.value)}
                  placeholder="e.g. 18, 12, 5"
                />
                <span className="percent-symbol">%</span>
              </div>
              <span className="input-hint">Enter any percentage (0 - 50%)</span>
            </div>

            <div className="plan-input-group">
              <label htmlFor={`tax-mode-${entry.id}`}>GST Treatment</label>
              <select
                id={`tax-mode-${entry.id}`}
                className="plan-select"
                value={taxMode}
                onChange={(e) => setTaxMode(e.target.value as PlanDraft['taxMode'])}
              >
                <option value="inclusive">GST Included in entered price</option>
                <option value="exclusive">GST Added on top of price</option>
              </select>
            </div>
          </>
        )}

        <div className="plan-input-group">
          <label htmlFor={`badge-${entry.id}`}>Offer / Promo Tag</label>
          <input
            id={`badge-${entry.id}`}
            type="text"
            className="plan-select"
            maxLength={32}
            value={badge}
            onChange={(e) => setBadge(e.target.value)}
            placeholder="e.g. Popular, 15 days, Save 20%"
          />
        </div>

        <div className={`plan-price-math-box ${!isGstEnabled ? 'no-gst-math' : ''}`}>
          {isGstEnabled ? (
            <>
              <div className="math-summary-line">
                <span>Price before GST</span>
                <strong>{money(priceCalc.base)}</strong>
              </div>
              <div className="math-summary-line">
                <span>GST ({validPercent}%)</span>
                <strong>{money(priceCalc.tax)}</strong>
              </div>
              <div className="math-total-line">
                <span>Employer Pays</span>
                <strong>{money(priceCalc.total)}</strong>
              </div>
            </>
          ) : (
            <div className="math-total-line">
              <span>Total Employer Pays</span>
              <strong>{money(numPrice * 100)}</strong>
            </div>
          )}
        </div>

        <div className="plan-quotas-list">
          <div className="plan-quota-item">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><polyline points="20 6 9 17 4 12"/></svg>
            <span><strong>{jobCredits}</strong> Job Post{jobCredits === 1 ? '' : 's'} (Live {listingDays} days)</span>
          </div>
          <div className="plan-quota-item">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><polyline points="20 6 9 17 4 12"/></svg>
            <span><strong>{profileUnlockLimit}</strong> Profile Unlocks</span>
          </div>
          <div className="plan-quota-item">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><polyline points="20 6 9 17 4 12"/></svg>
            <span>{current?.reach === 'statewide' ? 'All Tamil Nadu Reach' : 'One District Reach'}</span>
          </div>
        </div>

        {showAdvanced && (
          <div className="plan-advanced-box">
            <div className="plan-input-group">
              <label>Job Posts</label>
              <input
                type="number"
                min="1"
                className="plan-select"
                value={jobCredits}
                onChange={(e) => setJobCredits(Math.max(1, Number(e.target.value)))}
              />
            </div>
            <div className="plan-input-group">
              <label>Days Live</label>
              <input
                type="number"
                min="1"
                className="plan-select"
                value={listingDays}
                onChange={(e) => setListingDays(Math.max(1, Number(e.target.value)))}
              />
            </div>
            <div className="plan-input-group">
              <label>Subscription duration (days)</label>
              <input type="number" min="1" max="365" className="plan-select"
                value={durationDays} onChange={(e) => setDurationDays(Math.max(1, Number(e.target.value)))} />
            </div>
            <div className="plan-input-group" style={{ gridColumn: '1 / -1' }}>
              <label>Profile Unlocks</label>
              <input
                type="number"
                min="0"
                className="plan-select"
                value={profileUnlockLimit}
                onChange={(e) => setProfileUnlockLimit(Math.max(0, Number(e.target.value)))}
              />
            </div>
            <div className="plan-input-group" style={{ gridColumn: '1 / -1' }}>
              <div className="benefits-label-row">
                <label>Plan Benefits ({features.length}/8)</label>
                <span className="benefits-hint">Shown as checkmarks in employer app</span>
              </div>
              <div className="plan-benefits-manager">
                {features.length > 0 && (
                  <div className="benefits-list">
                    {features.map((feature, idx) => (
                      <div key={idx} className="benefit-row">
                        <span className="benefit-check-icon">✓</span>
                        <span className="benefit-text">{feature}</span>
                        <button
                          type="button"
                          className="benefit-remove-btn"
                          title="Remove benefit"
                          onClick={() => setFeatures(features.filter((_, i) => i !== idx))}
                        >
                          ✕
                        </button>
                      </div>
                    ))}
                  </div>
                )}
                {features.length < 8 ? (
                  <div className="benefit-add-row">
                    <input
                      type="text"
                      className="plan-select benefit-add-input"
                      maxLength={120}
                      placeholder="Add a benefit and press Enter..."
                      value={newBenefit}
                      onChange={(e) => setNewBenefit(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') {
                          e.preventDefault();
                          const trimmed = newBenefit.trim();
                          if (trimmed && features.length < 8) {
                            setFeatures([...features, trimmed]);
                            setNewBenefit('');
                          }
                        }
                      }}
                    />
                    <button
                      type="button"
                      className="benefit-add-btn"
                      disabled={!newBenefit.trim()}
                      onClick={() => {
                        const trimmed = newBenefit.trim();
                        if (trimmed && features.length < 8) {
                          setFeatures([...features, trimmed]);
                          setNewBenefit('');
                        }
                      }}
                    >
                      + Add
                    </button>
                  </div>
                ) : (
                  <p className="benefits-limit-notice">Maximum 8 benefits reached</p>
                )}
              </div>
            </div>
            {isPublished && (
              <div className="plan-advanced-footer">
                <button
                  className="plan-archive-link"
                  disabled={busy || cardBusy}
                  type="button"
                  onClick={() => {
                    if (window.confirm(`Archive "${current?.name || entry.id}"? It will no longer be visible to employers in the app.`)) {
                      onArchive(entry.id);
                    }
                  }}
                >
                  🗑️ Archive this plan
                </button>
              </div>
            )}
          </div>
        )}
      </div>

      <div className="plan-card-actions">
        <button
          className="plan-publish-btn"
          disabled={busy || cardBusy || numPrice <= 0}
          type="button"
          onClick={async () => {
            setCardBusy(true);
            try {
              await onSaveAndPublish(entry.id, draft);
            } finally {
              setCardBusy(false);
            }
          }}
        >
          {cardBusy ? 'Updating & Publishing...' : 'Update & Publish Price'}
        </button>

        <button
          type="button"
          className={`plan-customize-toggle-btn ${showAdvanced ? 'is-expanded' : ''}`}
          onClick={() => setShowAdvanced(!showAdvanced)}
        >
          <span>{showAdvanced ? '▲ Close quotas & limits' : '⚙️ Customize quotas & limits ▾'}</span>
        </button>
      </div>
    </div>
  );
}
