import { supabaseAdmin } from '../config/supabase.js';
import { firebaseApp } from '../config/firebase.js';
import { getFirestore } from 'firebase-admin/firestore';

export function catalogDb() {
  if (firebaseApp) {
    try {
      return getFirestore(firebaseApp);
    } catch (_) {}
  }
  return null;
}

const tiers = new Set(['standard', 'featured', 'elite']);
const taxModes = new Set(['inclusive', 'exclusive']);
const reaches = new Set(['district', 'statewide']);

export const initialPlanDrafts = [
  { id: 'standard_15', name: 'Starter', tier: 'standard', badge: '15 days', pricePaise: 236000,
    taxMode: 'inclusive', taxRateBps: 1800, jobCredits: 1, listingDays: 15,
    creditValidityDays: 15, profileUnlockLimit: 25, reach: 'district', sortOrder: 0,
    features: ['One local job for 15 days', '25 applicant profile unlocks', 'Contact access for unlocked applicants'] },
  { id: 'featured_30', name: 'Premium', tier: 'featured', badge: '30 days', pricePaise: 375000,
    taxMode: 'inclusive', taxRateBps: 1800, jobCredits: 1, listingDays: 30,
    creditValidityDays: 30, profileUnlockLimit: 100, reach: 'district', sortOrder: 2,
    features: ['One featured local job for 30 days', '100 applicant profile unlocks', 'Contact access for unlocked applicants'] },
  { id: 'elite_all_tn', name: 'Elite Tamil Nadu', tier: 'elite', badge: 'Statewide', pricePaise: 2000000,
    taxMode: 'inclusive', taxRateBps: 1800, jobCredits: 1, listingDays: 30,
    creditValidityDays: 30, profileUnlockLimit: 300, reach: 'statewide', sortOrder: 3,
    features: ['One statewide job for 30 days', '300 applicant profile unlocks', 'Contact access for unlocked applicants'] },
];

function integer(value, min, max, name) {
  if (!Number.isInteger(value) || value < min || value > max) {
    throw Object.assign(new Error(`${name} must be between ${min} and ${max}.`), { status: 400 });
  }
  return value;
}

function shortText(value, max, name) {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > max) {
    throw Object.assign(new Error(`Enter a valid ${name}.`), { status: 400 });
  }
  return value.trim();
}

export function validatePlanDraft(input) {
  if (!input || typeof input !== 'object') {
    throw Object.assign(new Error('Enter plan details.'), { status: 400 });
  }
  const tier = input.tier;
  const taxMode = input.taxMode;
  const reach = input.reach;
  if (!tiers.has(tier) || !taxModes.has(taxMode) || !reaches.has(reach)) {
    throw Object.assign(new Error('Choose a valid tier, tax mode and reach.'), { status: 400 });
  }
  const pricePaise = integer(input.pricePaise, 0, 100000000, 'Price');
  const taxRateBps = integer(input.taxRateBps, 0, 5000, 'GST rate');
  if (pricePaise < 100) {
    throw Object.assign(new Error('Paid plans must cost at least ₹1.'), { status: 400 });
  }
  if (tier !== 'elite' && reach === 'statewide') {
    throw Object.assign(new Error('Statewide reach is available only to Elite plans.'), { status: 400 });
  }
  if (!Array.isArray(input.features) || input.features.length > 8 ||
      input.features.some((feature) => typeof feature !== 'string' || feature.trim().length > 120)) {
    throw Object.assign(new Error('Enter up to eight short plan features.'), { status: 400 });
  }
  return {
    name: shortText(input.name, 70, 'plan name'),
    tier,
    badge: typeof input.badge === 'string' ? input.badge.trim().slice(0, 32) : '',
    pricePaise,
    taxMode,
    taxRateBps,
    jobCredits: integer(input.jobCredits, 1, 50, 'Job credits'),
    listingDays: integer(input.listingDays, 1, 90, 'Listing days'),
    creditValidityDays: integer(input.creditValidityDays, 1, 365, 'Plan validity'),
    profileUnlockLimit: integer(input.profileUnlockLimit, 0, 1000, 'Profile unlock limit'),
    reach,
    sortOrder: integer(input.sortOrder, 0, 1000, 'Display order'),
    features: input.features.map((feature) => feature.trim()).filter(Boolean),
  };
}

export function priceBreakdown(plan) {
  const { pricePaise, taxRateBps, taxMode } = plan;
  const basePaise = taxMode === 'inclusive'
    ? Math.round(pricePaise * 10000 / (10000 + taxRateBps))
    : pricePaise;
  const taxPaise = taxMode === 'inclusive'
    ? pricePaise - basePaise
    : Math.round(pricePaise * taxRateBps / 10000);
  return { basePaise, taxPaise, totalPaise: basePaise + taxPaise };
}

export function publicPlan(id, version, plan) {
  const price = priceBreakdown(plan);
  const rupees = (paise) => `₹${(paise / 100).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  return {
    id, version, ...plan, ...price, amountPaise: price.totalPaise, currency: 'INR',
    priceDisplay: rupees(price.totalPaise),
    gstDisplay: plan.taxRateBps === 0
      ? ''
      : plan.taxMode === 'inclusive'
        ? `Includes ${rupees(price.taxPaise)} GST (${plan.taxRateBps / 100}%)`
        : `${rupees(price.basePaise)} + ${rupees(price.taxPaise)} GST (${plan.taxRateBps / 100}%)`,
    locationsCovered: plan.reach === 'statewide' ? 'Tamil Nadu' : 'One district',
  };
}

export async function listPublishedPlans() {
  try {
    const { data, error } = await supabaseAdmin
      .from('employer_plans')
      .select('*')
      .eq('is_active', true)
      .order('sort_order', { ascending: true });

    if (!error && data && data.length > 0) {
      return data.map((d) => {
        const planData = {
          name: d.name,
          tier: d.tier || 'standard',
          badge: d.badge || '',
          pricePaise: d.price_paise || (d.price ? Math.round(d.price * 100) : 236000),
          taxMode: d.tax_mode || 'inclusive',
          taxRateBps: d.tax_rate_bps || 1800,
          jobCredits: d.job_credits || d.job_post_quota || 1,
          listingDays: d.listing_days || 30,
          creditValidityDays: d.credit_validity_days || 30,
          profileUnlockLimit: d.profile_unlock_limit || 25,
          reach: d.reach || 'district',
          sortOrder: d.sort_order || 0,
          features: Array.isArray(d.features) ? d.features : ['Verified job posting', 'Applicant unlocks'],
        };
        return publicPlan(d.id, d.version || 1, planData);
      });
    }
  } catch (_) {}

  return initialPlanDrafts.map((draft) => publicPlan(draft.id, 1, draft));
}

export async function publishedPlan(id) {
  try {
    const { data, error } = await supabaseAdmin
      .from('employer_plans')
      .select('*')
      .eq('id', id)
      .eq('is_active', true)
      .maybeSingle();

    if (!error && data) {
      const planData = {
        name: data.name,
        tier: data.tier || 'standard',
        badge: data.badge || '',
        pricePaise: data.price_paise || (data.price ? Math.round(data.price * 100) : 236000),
        taxMode: data.tax_mode || 'inclusive',
        taxRateBps: data.tax_rate_bps || 1800,
        jobCredits: data.job_credits || data.job_post_quota || 1,
        listingDays: data.listing_days || 30,
        creditValidityDays: data.credit_validity_days || 30,
        profileUnlockLimit: data.profile_unlock_limit || 25,
        reach: data.reach || 'district',
        sortOrder: data.sort_order || 0,
        features: Array.isArray(data.features) ? data.features : [],
      };
      return publicPlan(data.id, data.version || 1, planData);
    }
  } catch (_) {}

  const local = initialPlanDrafts.find((p) => p.id === id);
  if (local) {
    return publicPlan(local.id, 1, local);
  }

  throw Object.assign(new Error('This plan is unavailable.'), { status: 404 });
}

export async function seedPlanDrafts(adminUid) {
  for (const draft of initialPlanDrafts) {
    const valid = validatePlanDraft(draft);
    await supabaseAdmin.from('employer_plans').upsert({
      id: draft.id,
      name: valid.name,
      tier: valid.tier,
      badge: valid.badge,
      price_paise: valid.pricePaise,
      tax_mode: valid.taxMode,
      tax_rate_bps: valid.taxRateBps,
      job_credits: valid.jobCredits,
      listing_days: valid.listingDays,
      credit_validity_days: valid.creditValidityDays,
      profile_unlock_limit: valid.profileUnlockLimit,
      reach: valid.reach,
      sort_order: valid.sortOrder,
      features: valid.features,
      is_active: true,
      updated_at: new Date().toISOString(),
    });
  }
}
