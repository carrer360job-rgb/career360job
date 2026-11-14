import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { firebaseApp } from '../config/firebase.js';

const tiers = new Set(['free', 'standard', 'featured', 'elite']);
const taxModes = new Set(['inclusive', 'exclusive']);
const reaches = new Set(['district', 'statewide']);

export const initialPlanDrafts = [
  { id: 'free_starter', name: 'Free Starter', tier: 'free', badge: 'Free once', pricePaise: 0,
    taxMode: 'inclusive', taxRateBps: 0, jobCredits: 1, listingDays: 7,
    creditValidityDays: 7, profileUnlockLimit: 0, reach: 'district', sortOrder: 0,
    features: ['One local job for 7 days', 'Applicant summaries', 'Candidates can contact you'] },
  { id: 'standard_15', name: 'Starter', tier: 'standard', badge: '15 days', pricePaise: 236000,
    taxMode: 'inclusive', taxRateBps: 1800, jobCredits: 1, listingDays: 15,
    creditValidityDays: 15, profileUnlockLimit: 25, reach: 'district', sortOrder: 1,
    features: ['One local job for 15 days', '25 applicant profile unlocks', 'Resume and contact access for unlocked applicants'] },
  { id: 'featured_30', name: 'Premium', tier: 'featured', badge: '30 days', pricePaise: 375000,
    taxMode: 'inclusive', taxRateBps: 1800, jobCredits: 1, listingDays: 30,
    creditValidityDays: 30, profileUnlockLimit: 100, reach: 'district', sortOrder: 2,
    features: ['One featured local job for 30 days', '100 applicant profile unlocks', 'Resume and contact access for unlocked applicants'] },
  { id: 'elite_all_tn', name: 'Elite Tamil Nadu', tier: 'elite', badge: 'Statewide', pricePaise: 2000000,
    taxMode: 'inclusive', taxRateBps: 1800, jobCredits: 1, listingDays: 30,
    creditValidityDays: 30, profileUnlockLimit: 300, reach: 'statewide', sortOrder: 3,
    features: ['One statewide job for 30 days', '300 applicant profile unlocks', 'Resume and contact access for unlocked applicants'] },
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
  if ((tier === 'free') !== (pricePaise === 0) || (pricePaise === 0 && taxRateBps !== 0)) {
    throw Object.assign(new Error('Free plans must have zero price and tax rate.'), { status: 400 });
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
    gstDisplay: plan.pricePaise === 0 ? 'Free' : plan.taxMode === 'inclusive'
      ? `Includes ${rupees(price.taxPaise)} GST (${plan.taxRateBps / 100}%)`
      : `${rupees(price.basePaise)} + ${rupees(price.taxPaise)} GST (${plan.taxRateBps / 100}%)`,
    locationsCovered: plan.reach === 'statewide' ? 'Tamil Nadu' : 'One district',
  };
}

export function catalogDb() {
  if (!firebaseApp) throw Object.assign(new Error('Firebase Admin is unavailable.'), { status: 503 });
  return getFirestore(firebaseApp);
}

export async function listPublishedPlans() {
  const snapshot = await catalogDb().collection('employer_plans').get();
  return snapshot.docs.flatMap((doc) => {
    const { published, version } = doc.data();
    return published?.active ? [publicPlan(doc.id, version, published)] : [];
  }).sort((a, b) => a.sortOrder - b.sortOrder);
}

export async function publishedPlan(id) {
  const snapshot = await catalogDb().collection('employer_plans').doc(id).get();
  const { published, version } = snapshot.data() ?? {};
  if (!published?.active) {
    throw Object.assign(new Error('This plan is unavailable.'), { status: 404 });
  }
  return publicPlan(id, version, published);
}

export async function seedPlanDrafts(adminUid) {
  const database = catalogDb();
  const batch = database.batch();
  const existing = await database.collection('employer_plans').get();
  if (!existing.empty) {
    throw Object.assign(new Error('Plan catalog already exists.'), { status: 409 });
  }
  for (const { id, ...draft } of initialPlanDrafts) {
    batch.create(database.collection('employer_plans').doc(id), {
      draft: validatePlanDraft(draft), version: 0, createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(), updatedBy: adminUid,
    });
  }
  await batch.commit();
}
