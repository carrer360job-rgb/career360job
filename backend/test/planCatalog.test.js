import test from 'node:test';
import assert from 'node:assert/strict';
import { priceBreakdown, publicPlan, validatePlanDraft, initialPlanDrafts } from '../src/services/planCatalog.js';

test('GST inclusive and exclusive totals use exact paise and never trust display strings', () => {
  const draft = validatePlanDraft(initialPlanDrafts[0]);
  assert.deepEqual(priceBreakdown(draft), { basePaise: 200000, taxPaise: 36000, totalPaise: 236000 });
  const exclusive = validatePlanDraft({ ...draft, taxMode: 'exclusive', pricePaise: 200000 });
  assert.deepEqual(priceBreakdown(exclusive), { basePaise: 200000, taxPaise: 36000, totalPaise: 236000 });
  assert.equal(publicPlan('standard_15', 3, exclusive).amountPaise, 236000);
});

test('plan drafts reject invalid pricing and benefits', () => {
  const draft = initialPlanDrafts[0];
  assert.throws(() => validatePlanDraft({ ...draft, pricePaise: 50 }), /Paid plans must cost at least/);
  assert.throws(() => validatePlanDraft({ ...draft, profileUnlockLimit: -1 }), /profile unlock/i);
  assert.throws(() => validatePlanDraft({ ...initialPlanDrafts[0], reach: 'statewide' }), /Statewide/);
  assert.throws(() => validatePlanDraft({ ...initialPlanDrafts[0], taxRateBps: 6000 }), /GST rate/);
});

test('No GST (0% taxRateBps) produces empty gstDisplay and zero taxPaise', () => {
  const noGstDraft = validatePlanDraft({ ...initialPlanDrafts[0], taxRateBps: 0, pricePaise: 250000 });
  const breakdown = priceBreakdown(noGstDraft);
  assert.equal(breakdown.taxPaise, 0);
  assert.equal(breakdown.basePaise, 250000);
  assert.equal(breakdown.totalPaise, 250000);

  const published = publicPlan('standard_15', 4, noGstDraft);
  assert.equal(published.gstDisplay, '');
  assert.equal(published.amountPaise, 250000);
});

test('Custom manual GST rates format correctly in gstDisplay', () => {
  const customGstDraft = validatePlanDraft({ ...initialPlanDrafts[0], taxRateBps: 1850, pricePaise: 200000, taxMode: 'exclusive' });
  const published = publicPlan('standard_15', 5, customGstDraft);
  assert.match(published.gstDisplay, /18\.5%/);
});
