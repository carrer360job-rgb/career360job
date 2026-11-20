import { supabaseAdmin } from '../config/supabase.js';

const tiers = new Set(['monthly', 'quarterly', 'yearly']);
const taxModes = new Set(['inclusive', 'exclusive']);
const reaches = new Set(['district', 'statewide']);
export const subscriptionPlanIds = [...tiers];

export const initialPlanDrafts = [
  { id: 'monthly', name: 'Monthly', tier: 'monthly', badge: '1 month', pricePaise: 19900,
    taxMode: 'inclusive', taxRateBps: 1800, jobCredits: 10, listingDays: 30,
    creditValidityDays: 30, profileUnlockLimit: 1000, reach: 'district', sortOrder: 0,
    features: ['10 job posts', 'Valid for one month', 'Manage applicants'] },
  { id: 'quarterly', name: 'Quarterly', tier: 'quarterly', badge: '3 months', pricePaise: 49900,
    taxMode: 'inclusive', taxRateBps: 1800, jobCredits: 50, listingDays: 90,
    creditValidityDays: 90, profileUnlockLimit: 1000, reach: 'district', sortOrder: 1,
    features: ['50 job posts', 'Valid for three months', 'Manage applicants'] },
  { id: 'yearly', name: 'Yearly', tier: 'yearly', badge: '12 months', pricePaise: 199900,
    taxMode: 'inclusive', taxRateBps: 1800, jobCredits: 150, listingDays: 365,
    creditValidityDays: 365, profileUnlockLimit: 1000, reach: 'district', sortOrder: 2,
    features: ['150 job posts', 'Valid for twelve months', 'Manage applicants'] },
];

function integer(value, min, max, name) {
  if (!Number.isInteger(value) || value < min || value > max) {
    throw Object.assign(new Error(`${name} must be between ${min} and ${max}.`), { status: 400 });
  }
  return value;
}

export function validatePlanDraft(input) {
  if (!input || typeof input !== 'object' || !tiers.has(input.tier) ||
      !taxModes.has(input.taxMode) || !reaches.has(input.reach) ||
      typeof input.name !== 'string' || !input.name.trim() || input.name.length > 70 ||
      !Array.isArray(input.features) || input.features.length > 8 ||
      input.features.some((feature) => typeof feature !== 'string' || feature.length > 120)) {
    throw Object.assign(new Error('Enter valid subscription plan details.'), { status: 400 });
  }
  return {
    name: input.name.trim(), tier: input.tier,
    badge: typeof input.badge === 'string' ? input.badge.trim().slice(0, 32) : '',
    pricePaise: integer(input.pricePaise, 100, 100000000, 'Price'),
    taxMode: input.taxMode, taxRateBps: integer(input.taxRateBps, 0, 5000, 'GST rate'),
    jobCredits: integer(input.jobCredits, 1, 10000, 'Job posts'),
    listingDays: integer(input.listingDays, 1, 365, 'Listing days'),
    creditValidityDays: integer(input.creditValidityDays, 1, 365, 'Plan duration'),
    profileUnlockLimit: integer(input.profileUnlockLimit, 0, 100000, 'Profile unlock limit'),
    reach: input.reach, sortOrder: integer(input.sortOrder, 0, 1000, 'Display order'),
    features: input.features.map((feature) => feature.trim()).filter(Boolean),
  };
}

export function priceBreakdown(plan) {
  const { pricePaise, taxRateBps, taxMode } = plan;
  const basePaise = taxMode === 'inclusive'
    ? Math.round(pricePaise * 10000 / (10000 + taxRateBps)) : pricePaise;
  const taxPaise = taxMode === 'inclusive' ? pricePaise - basePaise
    : Math.round(pricePaise * taxRateBps / 10000);
  return { basePaise, taxPaise, totalPaise: basePaise + taxPaise };
}

export function publicPlan(id, version, plan) {
  const price = priceBreakdown(plan);
  const rupees = (paise) => `₹${(paise / 100).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  return {
    id, version, ...plan, ...price, amountPaise: price.totalPaise, currency: 'INR',
    priceDisplay: rupees(price.totalPaise),
    gstDisplay: plan.taxRateBps === 0 ? '' : plan.taxMode === 'inclusive'
      ? `Includes ${rupees(price.taxPaise)} GST (${plan.taxRateBps / 100}%)`
      : `${rupees(price.basePaise)} + ${rupees(price.taxPaise)} GST (${plan.taxRateBps / 100}%)`,
    locationsCovered: plan.reach === 'statewide' ? 'Tamil Nadu' : 'One district per job',
  };
}

function fromRow(row) {
  return {
    name: row.name, tier: row.tier, badge: row.badge || '',
    pricePaise: Number(row.price_paise), taxMode: row.tax_mode || 'inclusive',
    taxRateBps: row.tax_rate_bps ?? 1800, jobCredits: row.job_credits,
    listingDays: row.listing_days, creditValidityDays: row.credit_validity_days,
    profileUnlockLimit: row.profile_unlock_limit ?? 1000,
    reach: row.reach || 'district', sortOrder: row.sort_order || 0,
    features: Array.isArray(row.features) ? row.features : [],
  };
}

export async function listPublishedPlans() {
  const { data, error } = await supabaseAdmin.from('employer_plans').select('*')
    .in('id', subscriptionPlanIds).eq('is_active', true).order('sort_order', { ascending: true });
  if (error) throw error;
  return (data || []).map((row) => publicPlan(row.id, row.version, fromRow(row)));
}

export async function publishedPlan(id) {
  if (!tiers.has(id)) throw Object.assign(new Error('This plan is unavailable.'), { status: 404 });
  const { data, error } = await supabaseAdmin.from('employer_plans').select('*')
    .eq('id', id).eq('is_active', true).maybeSingle();
  if (error) throw error;
  if (!data) throw Object.assign(new Error('This plan is unavailable.'), { status: 404 });
  return publicPlan(data.id, data.version, fromRow(data));
}
