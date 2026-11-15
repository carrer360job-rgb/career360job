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
