import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import express from 'express';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { v2 as cloudinary } from 'cloudinary';
import { auth, firebaseApp } from '../config/firebase.js';
import { verifyFirebaseToken, verifyAdminToken } from '../middlewares/authMiddleware.js';
import { requireAdmin } from '../middlewares/adminMiddleware.js';
import { listPublishedPlans, publishedPlan } from '../services/planCatalog.js';

export const employerRouter = express.Router();
export const employerWebhookRouter = express.Router();

const statuses = new Set(['Shortlisted', 'Interview', 'Rejected', 'Hired']);

function paymentReady() {
  const keyId = process.env.RAZORPAY_KEY_ID || '';
  const secret = process.env.RAZORPAY_KEY_SECRET || '';
  const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET || '';
  return Boolean(firebaseApp && keyId && secret && webhookSecret &&
    (keyId.startsWith('rzp_test_') || (keyId.startsWith('rzp_live_') && process.env.RAZORPAY_ENABLE_LIVE === 'true')));
}

function db() {
  if (!firebaseApp) throw Object.assign(new Error('Employer backend is not configured.'), { status: 503 });
  return getFirestore(firebaseApp);
}

function verified(req, res, next) {
  if (req.user.email_verified === true) return next();
  return res.status(403).json({ error: { message: 'Verify your email before continuing.' } });
}

export function hasTrustedApproval(profile) {
  return profile?.status === 'approved' &&
    typeof profile.reviewedBy === 'string' && profile.reviewedBy.length > 0 &&
    (profile.reviewedAt?.toMillis?.() ?? 0) > 0;
}

async function approvedEmployer(uid) {
  const database = db();
  const [user, employer] = await Promise.all([
    database.collection('users').doc(uid).get(),
    database.collection('employers').doc(uid).get(),
  ]);
  if (user.data()?.role !== 'employer' || !hasTrustedApproval(employer.data())) {
    throw Object.assign(new Error('Your company must be approved before this action.'), { status: 403 });
  }
  return employer;
}

function safeString(value, max, min = 1) {
  if (typeof value !== 'string') return null;
  const clean = value.trim();
  return clean.length >= min && clean.length <= max ? clean : null;
}

function jobFields(body = {}) {
  const title = safeString(body.title, 100, 3);
  const description = safeString(body.description, 5000, 30);
  const salaryText = safeString(body.salaryText, 80, 3);
  const locationCity = safeString(body.district, 80, 2);
  const category = safeString(body.category, 80, 2);
  const workMode = safeString(body.workMode, 20, 2);
  const vacanciesCount = Number(body.vacanciesCount);
  const contactName = safeString(body.contactName, 80, 2);
  const phone = safeString(body.phone, 20, 7);
  const whatsappNumber = safeString(body.whatsappNumber, 20, 7);
  const email = safeString(body.email, 120, 5);

  if (!title || !description || !salaryText || !locationCity || !category ||
      !['On-site', 'Hybrid', 'Remote'].includes(workMode) ||
      !Number.isInteger(vacanciesCount) || vacanciesCount < 1 || vacanciesCount > 999) {
    throw Object.assign(new Error('Enter valid job details before publishing.'), { status: 400 });
  }
  const result = { title, description, salaryText, locationCity, category, workMode, vacanciesCount };
  if (contactName) result.contactName = contactName;
  if (phone) result.phone = phone;
  if (whatsappNumber) result.whatsappNumber = whatsappNumber;
  if (email) result.email = email;
  return result;
}

async function razorpayRequest(path, options = {}) {
  const key = Buffer.from(`${process.env.RAZORPAY_KEY_ID}:${process.env.RAZORPAY_KEY_SECRET}`).toString('base64');
  const response = await fetch(`https://api.razorpay.com/v1${path}`, {
    ...options,
    headers: { Authorization: `Basic ${key}`, 'Content-Type': 'application/json', ...options.headers },
    signal: AbortSignal.timeout(12000),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error('[Razorpay]', response.status, data.error?.code || 'unknown');
    throw Object.assign(new Error('Payment service is unavailable. Try again later.'), { status: 502 });
  }
  return data;
}

export function signaturesMatch(message, signature, secret) {
  if (typeof signature !== 'string' || !/^[0-9a-f]{64}$/i.test(signature)) return false;
  const expected = createHmac('sha256', secret).update(message).digest();
  return timingSafeEqual(expected, Buffer.from(signature, 'hex'));
}

async function grantCredits(orderId, payment) {
  const database = db();
  const orderRef = database.collection('employer_orders').doc(orderId);
  return database.runTransaction(async (transaction) => {
    const order = await transaction.get(orderRef);
    const record = order.data();
    if (!record) throw Object.assign(new Error('Unknown payment order.'), { status: 404 });
    if (record.status === 'paid') return { alreadyGranted: true };
    if (payment.order_id !== orderId || payment.status !== 'captured' ||
        payment.amount !== record.amountPaise || payment.currency !== 'INR') {
      throw Object.assign(new Error('Payment details do not match the order.'), { status: 400 });
    }
    const employerRef = database.collection('employers').doc(record.employerUid);
    const employer = await transaction.get(employerRef);
    const entitlementRef = database.collection('employer_entitlements').doc(record.employerUid);
    const previousEntitlement = await transaction.get(entitlementRef);
    if (!employer.exists) throw Object.assign(new Error('Company not found.'), { status: 404 });
    const now = Date.now();
    const existingExpiry = employer.data()?.creditsExpireAt?.toMillis?.() ?? 0;
    const activeCredits = existingExpiry > now ? employer.data()?.postingCredits ?? 0 : 0;
    const nextExpiry = Math.max(existingExpiry, now + record.creditValidityDays * 86400000);
    const termEnd = now + record.creditValidityDays * 86400000;
    // A captured payment is always fulfilled. If two pending orders complete,
    // the latest successful capture starts a new term; earlier credits remain.
    transaction.update(employerRef, {
      postingCredits: activeCredits + record.jobCredits,
      listingDays: record.listingDays,
      creditsExpireAt: Timestamp.fromMillis(nextExpiry),
      activePlan: record.planId,
      activePlanName: record.planName,
      planTier: record.tier,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(entitlementRef, {
      employerUid: record.employerUid, planId: record.planId,
      planVersion: record.planVersion ?? 1, planName: record.planName,
      tier: record.tier, profileUnlockLimit: record.profileUnlockLimit ?? 0,
      unlocksUsed: 0, orderId,
      startsAt: Timestamp.fromMillis(now), expiresAt: Timestamp.fromMillis(termEnd),
      previousOrderId: previousEntitlement.data()?.orderId ?? null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(orderRef, {
      status: 'paid',
      paymentId: payment.id,
      paidAt: FieldValue.serverTimestamp(),
    });
    transaction.create(database.collection('users').doc(record.employerUid).collection('notifications').doc(), {
      title: 'Posting credit ready',
      body: `${record.jobCredits} job posting credit${record.jobCredits === 1 ? '' : 's'} added to your company account.`,
      type: 'employer_payment',
      createdAt: FieldValue.serverTimestamp(),
      readAt: null,
    });
    return { alreadyGranted: false };
  });
}

function handleError(res, error) {
  console.error('[Employer API]', error);
  return res.status(error.status || 500).json({ error: { message: error.status ? error.message : 'Could not complete this request.' } });
}

employerRouter.get('/plans', async (req, res) => {
  try {
    res.set('Cache-Control', 'no-store');
    res.json({ plans: await listPublishedPlans(), checkoutReady: paymentReady() });
  } catch (error) {
    handleError(res, error);
  }
});

employerRouter.post('/orders', verifyFirebaseToken, verified, async (req, res) => {
  try {
    await approvedEmployer(req.user.uid);
    const planId = req.body?.planId;
    if (typeof planId !== 'string') return res.status(400).json({ error: { message: 'Choose a plan.' } });
    const plan = await publishedPlan(planId);

    // Grant the starter credit once, atomically, after company approval.
    if (plan.amountPaise === 0) {
      const now = Date.now();
      const database = db();
      const employerRef = database.collection('employers').doc(req.user.uid);
      await database.runTransaction(async (transaction) => {
        const employer = await transaction.get(employerRef);
        const profile = employer.data();
        if (!hasTrustedApproval(profile)) {
          throw Object.assign(new Error('Company approval is required.'), { status: 403 });
        }
        if (profile.freeStarterUsed === true || profile.activePlan === 'free_starter') {
          throw Object.assign(new Error('The free starter plan has already been used.'), { status: 409 });
        }
        const entitlementRef = database.collection('employer_entitlements').doc(req.user.uid);
        const existingEntitlement = await transaction.get(entitlementRef);
        const activePaid = existingEntitlement.data()?.tier !== 'free' &&
          (existingEntitlement.data()?.expiresAt?.toMillis?.() ?? 0) > now;
        if (activePaid) throw Object.assign(new Error('Your paid plan is still active.'), { status: 409 });
        const existingExpiry = profile.creditsExpireAt?.toMillis?.() ?? 0;
        const activeCredits = existingExpiry > now ? profile.postingCredits ?? 0 : 0;
        transaction.update(employerRef, {
          postingCredits: activeCredits + plan.jobCredits,
          listingDays: plan.listingDays,
          creditsExpireAt: Timestamp.fromMillis(Math.max(existingExpiry, now + plan.creditValidityDays * 86400000)),
          activePlan: plan.id,
          activePlanName: plan.name,
          planTier: plan.tier,
          freeStarterUsed: true,
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.set(entitlementRef, {
          employerUid: req.user.uid, planId: plan.id, planVersion: plan.version,
          planName: plan.name, tier: plan.tier, profileUnlockLimit: plan.profileUnlockLimit,
          unlocksUsed: 0, orderId: 'free_starter',
          startsAt: Timestamp.fromMillis(now),
          expiresAt: Timestamp.fromMillis(now + plan.creditValidityDays * 86400000),
          updatedAt: FieldValue.serverTimestamp(),
        });
      });

      return res.json({
        isFree: true,
        status: 'activated',
        planId: plan.id,
        message: 'Free Starter Plan activated! 1 free job posting credit has been added.',
      });
    }

    // One paid term at a time; renewal is manual after expiry.
    const entitlement = await db().collection('employer_entitlements').doc(req.user.uid).get();
    if (entitlement.data()?.tier !== 'free' &&
        (entitlement.data()?.expiresAt?.toMillis?.() ?? 0) > Date.now()) {
      return res.status(409).json({ error: { message: 'Your paid plan is still active. Renew after it expires.' } });
    }
    // Paid Plan - Requires Razorpay
    if (!paymentReady()) return res.status(503).json({ error: { message: 'Payments are not configured yet.' } });
    const created = await razorpayRequest('/orders', {
      method: 'POST',
      body: JSON.stringify({
        amount: plan.amountPaise,
        currency: plan.currency,
        receipt: `c360_${randomUUID().replaceAll('-', '').slice(0, 30)}`,
        notes: { employerUid: req.user.uid, planId: plan.id },
      }),
    });
    if (!created.id || created.amount !== plan.amountPaise || created.currency !== 'INR') {
      throw Object.assign(new Error('Payment order could not be confirmed.'), { status: 502 });
    }
    await db().collection('employer_orders').doc(created.id).create({
      employerUid: req.user.uid,
      planId: plan.id,
      planVersion: plan.version,
      planName: plan.name,
      tier: plan.tier,
      amountPaise: plan.amountPaise,
      basePaise: plan.basePaise,
      taxPaise: plan.taxPaise,
      taxMode: plan.taxMode,
      taxRateBps: plan.taxRateBps,
      currency: plan.currency,
      jobCredits: plan.jobCredits,
      listingDays: plan.listingDays,
      creditValidityDays: plan.creditValidityDays,
      profileUnlockLimit: plan.profileUnlockLimit,
      reach: plan.reach,
      status: 'created',
      createdAt: FieldValue.serverTimestamp(),
    });
    return res.json({ orderId: created.id, keyId: process.env.RAZORPAY_KEY_ID,
      amountPaise: plan.amountPaise, basePaise: plan.basePaise, taxPaise: plan.taxPaise,
      planVersion: plan.version, currency: 'INR' });
  } catch (error) { return handleError(res, error); }
});

employerRouter.post('/orders/verify', verifyFirebaseToken, verified, async (req, res) => {
  try {
    if (!paymentReady()) return res.status(503).json({ error: { message: 'Payments are unavailable.' } });
    const orderId = safeString(req.body?.orderId, 80);
    const paymentId = safeString(req.body?.paymentId, 80);
    const signature = req.body?.signature;
    if (!orderId || !paymentId || !signaturesMatch(`${orderId}|${paymentId}`, signature, process.env.RAZORPAY_KEY_SECRET)) {
      return res.status(400).json({ error: { message: 'Payment verification failed.' } });
    }
    const order = await db().collection('employer_orders').doc(orderId).get();
    if (order.data()?.employerUid !== req.user.uid) return res.status(403).json({ error: { message: 'This order belongs to another account.' } });
    const payment = await razorpayRequest(`/payments/${encodeURIComponent(paymentId)}`);
    const result = await grantCredits(orderId, payment);
    return res.json({ status: 'paid', ...result });
  } catch (error) { return handleError(res, error); }
});

employerWebhookRouter.post('/', express.raw({ type: 'application/json', limit: '256kb' }), async (req, res) => {
  try {
    const secret = process.env.RAZORPAY_WEBHOOK_SECRET;
    if (!secret || !firebaseApp || !Buffer.isBuffer(req.body) ||
        !signaturesMatch(req.body, req.header('x-razorpay-signature'), secret)) {
      return res.status(401).end();
    }
    const event = JSON.parse(req.body.toString('utf8'));
    if (event.event === 'payment.captured') {
      const payment = event.payload?.payment?.entity;
      if (payment?.order_id && payment?.id) await grantCredits(payment.order_id, payment);
    }
    return res.status(200).json({ received: true });
  } catch (error) { return handleError(res, error); }
});

employerRouter.post('/jobs', verifyFirebaseToken, verified, async (req, res) => {
  try {
    const fields = jobFields(req.body);
    const database = db();
    const employerRef = database.collection('employers').doc(req.user.uid);
    const entitlementRef = database.collection('employer_entitlements').doc(req.user.uid);
    const userRef = database.collection('users').doc(req.user.uid);
    const jobRef = database.collection('jobs').doc();
    await database.runTransaction(async (transaction) => {
      const [employer, user, entitlement] = await Promise.all([
        transaction.get(employerRef), transaction.get(userRef), transaction.get(entitlementRef),
      ]);
      const profile = employer.data();
      const grant = entitlement.data();
      if (user.data()?.role !== 'employer' || !hasTrustedApproval(profile)) {
        throw Object.assign(new Error('Your company is awaiting approval.'), { status: 403 });
      }
      if (!Number.isInteger(profile.postingCredits) || profile.postingCredits < 1 ||
          (profile.creditsExpireAt?.toMillis?.() ?? 0) <= Date.now() ||
          (grant?.expiresAt?.toMillis?.() ?? 0) <= Date.now()) {
        throw Object.assign(new Error('Buy a valid posting plan before publishing.'), { status: 402 });
      }
      const listingDays = Number.isInteger(profile.listingDays) ? profile.listingDays : 7;
      const isFeatured = grant.tier === 'featured' || grant.tier === 'elite';
      const isStatewide = grant.tier === 'elite' && req.body?.isStatewide !== false;
      if (!isStatewide && fields.locationCity === 'All Tamil Nadu') {
        throw Object.assign(new Error('Choose a district for this plan.'), { status: 400 });
      }

      transaction.create(jobRef, {
        ...fields,
        companyName: profile.companyName,
        employerUid: req.user.uid,
        contactName: fields.contactName || profile.contactName || '',
        phone: fields.phone || profile.phone || '',
        email: fields.email || profile.email || '',
        whatsappNumber: fields.whatsappNumber || profile.whatsappPhone || profile.phone || '',
        status: 'active',
        isVerified: true,
        isFeatured,
        isStatewide,
        planTier: profile.planTier || 'free',
        planName: profile.activePlanName || 'Free Starter Plan',
        postedAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromMillis(Date.now() + listingDays * 86400000),
      });
      transaction.update(employerRef, {
        postingCredits: FieldValue.increment(-1),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return res.status(201).json({ jobId: jobRef.id });
  } catch (error) { return handleError(res, error); }
});

employerRouter.patch('/jobs/:jobId', verifyFirebaseToken, verified, async (req, res) => {
  try {
    await approvedEmployer(req.user.uid);
    const fields = jobFields(req.body);
    const jobRef = db().collection('jobs').doc(req.params.jobId);
    const job = await jobRef.get();
    if (!job.exists || job.data().employerUid !== req.user.uid) return res.status(404).json({ error: { message: 'Job not found.' } });
    if (job.data().status !== 'active') return res.status(409).json({ error: { message: 'Only active jobs can be edited.' } });
    await jobRef.update({ ...fields, updatedAt: FieldValue.serverTimestamp() });
    return res.json({ jobId: jobRef.id });
  } catch (error) { return handleError(res, error); }
});

employerRouter.post('/jobs/:jobId/close', verifyFirebaseToken, verified, async (req, res) => {
  try {
    await approvedEmployer(req.user.uid);
    const jobRef = db().collection('jobs').doc(req.params.jobId);
    const job = await jobRef.get();
    if (!job.exists || job.data().employerUid !== req.user.uid) return res.status(404).json({ error: { message: 'Job not found.' } });
    if (job.data().status === 'active') await jobRef.update({ status: 'closed', closedAt: FieldValue.serverTimestamp() });
    return res.json({ status: 'closed' });
  } catch (error) { return handleError(res, error); }
});

employerRouter.patch('/applications/:applicationId/status', verifyFirebaseToken, verified, async (req, res) => {
  try {
    await approvedEmployer(req.user.uid);
    const status = req.body?.status;
    if (!statuses.has(status)) return res.status(400).json({ error: { message: 'Choose a valid application status.' } });
    const database = db();
    const applicationRef = database.collection('applications').doc(req.params.applicationId);
    await database.runTransaction(async (transaction) => {
      const application = await transaction.get(applicationRef);
      const data = application.data();
      if (!data || data.employerUid !== req.user.uid) {
        throw Object.assign(new Error('Application not found.'), { status: 404 });
      }
      if (data.status === status) return;
      transaction.update(applicationRef, { status, reviewedAt: FieldValue.serverTimestamp() });
      const notificationRef = database.collection('users').doc(data.candidateUid).collection('notifications').doc();
      transaction.create(notificationRef, {
        title: 'Application update',
        body: `Your application for ${data.jobTitle || 'a job'} is now ${status.toLowerCase()}.`,
        type: 'application_status',
        createdAt: FieldValue.serverTimestamp(),
        readAt: null,
      });
    });
    return res.json({ status });
  } catch (error) { return handleError(res, error); }
});

function activeEntitlement(data) {
  return data && (data.expiresAt?.toMillis?.() ?? 0) > Date.now();
}

async function ownedApplication(database, employerUid, id) {
  const application = await database.collection('applications').doc(id).get();
  if (!application.exists || application.data().employerUid !== employerUid) {
    throw Object.assign(new Error('Application not found.'), { status: 404 });
  }
  return application;
}

employerRouter.get('/entitlement', verifyFirebaseToken, verified, async (req, res) => {
  try {
    await approvedEmployer(req.user.uid);
    const doc = await db().collection('employer_entitlements').doc(req.user.uid).get();
    const data = doc.data();
    res.set('Cache-Control', 'no-store');
    res.json({ entitlement: data ? {
      planId: data.planId, planName: data.planName, tier: data.tier,
      profileUnlockLimit: data.profileUnlockLimit || 0, unlocksUsed: data.unlocksUsed || 0,
      expiresAt: data.expiresAt?.toDate?.().toISOString() ?? null,
      active: Boolean(activeEntitlement(data)),
    } : null });
  } catch (error) { return handleError(res, error); }
});

employerRouter.get('/applications', verifyFirebaseToken, verified, async (req, res) => {
  try {
    await approvedEmployer(req.user.uid);
    const database = db();
    const snapshot = await database.collection('applications')
      .where('employerUid', '==', req.user.uid).limit(200).get();
    const entitlement = await database.collection('employer_entitlements').doc(req.user.uid).get();
    const grant = entitlement.data();
    const unlocks = activeEntitlement(grant)
      ? await database.collection('employer_entitlements').doc(req.user.uid).collection('unlocks').get()
      : null;
    const unlockedCandidates = new Set(unlocks?.docs.filter((doc) => doc.data().orderId === grant.orderId)
      .map((doc) => doc.id) ?? []);
    const applications = snapshot.docs.map((doc) => {
      const a = doc.data();
      return {
        id: doc.id, candidateName: a.candidateName || 'Applicant',
        jobId: a.jobId, jobTitle: a.jobTitle || 'Job',
        education: a.education || '', experienceYears: a.experienceYears || '',
        status: a.status || 'Applied',
        appliedAt: a.appliedAt?.toDate?.().toISOString() ?? null,
        unlocked: unlockedCandidates.has(a.candidateUid),
      };
    }).sort((a, b) => (b.appliedAt || '').localeCompare(a.appliedAt || ''));
    res.set('Cache-Control', 'no-store');
    res.json({ applications, remainingUnlocks: activeEntitlement(grant)
      ? Math.max(0, (grant.profileUnlockLimit || 0) - (grant.unlocksUsed || 0)) : 0 });
  } catch (error) { return handleError(res, error); }
});

employerRouter.post('/applications/:applicationId/unlock', verifyFirebaseToken, verified, async (req, res) => {
  try {
    await approvedEmployer(req.user.uid);
    const database = db();
    const entitlementRef = database.collection('employer_entitlements').doc(req.user.uid);
    const appRef = database.collection('applications').doc(req.params.applicationId);
    const result = await database.runTransaction(async (tx) => {
      const [entitlement, application] = await Promise.all([tx.get(entitlementRef), tx.get(appRef)]);
      const grant = entitlement.data();
      const a = application.data();
      if (!a || a.employerUid !== req.user.uid) throw Object.assign(new Error('Application not found.'), { status: 404 });
      if (!activeEntitlement(grant)) throw Object.assign(new Error('Choose an active plan to unlock applicants.'), { status: 402 });
      const unlockRef = entitlementRef.collection('unlocks').doc(a.candidateUid);
      const unlocked = await tx.get(unlockRef);
      if (unlocked.data()?.orderId === grant.orderId) return { alreadyUnlocked: true };
      if ((grant.unlocksUsed || 0) >= (grant.profileUnlockLimit || 0)) {
        throw Object.assign(new Error('Your plan has no profile unlocks remaining.'), { status: 402 });
      }
      tx.set(unlockRef, {
        candidateUid: a.candidateUid, orderId: grant.orderId,
        applicationId: application.id, unlockedAt: FieldValue.serverTimestamp(),
      });
      tx.update(entitlementRef, { unlocksUsed: FieldValue.increment(1) });
      tx.create(database.collection('employer_access_audit').doc(), {
        employerUid: req.user.uid, candidateUid: a.candidateUid,
        applicationId: application.id, orderId: grant.orderId,
        action: 'profile_unlock', createdAt: FieldValue.serverTimestamp(),
      });
      return { alreadyUnlocked: false };
    });
    res.json({ status: 'unlocked', ...result });
  } catch (error) { return handleError(res, error); }
});

async function requireUnlocked(database, employerUid, applicationId) {
  const application = await ownedApplication(database, employerUid, applicationId);
  const entitlementRef = database.collection('employer_entitlements').doc(employerUid);
  const grant = (await entitlementRef.get()).data();
  const unlock = await entitlementRef.collection('unlocks').doc(application.data().candidateUid).get();
  if (!activeEntitlement(grant) || unlock.data()?.orderId !== grant.orderId) {
    throw Object.assign(new Error('Unlock this applicant with an active plan first.'), { status: 402 });
  }
  return application;
}

employerRouter.get('/applications/:applicationId/profile', verifyFirebaseToken, verified, async (req, res) => {
  try {
    await approvedEmployer(req.user.uid);
    const database = db();
    const application = await requireUnlocked(database, req.user.uid, req.params.applicationId);
    const candidate = (await database.collection('candidates').doc(application.data().candidateUid).get()).data() || {};
    const a = application.data();
    res.set('Cache-Control', 'no-store');
    res.json({ profile: {
      name: candidate.fullName || a.candidateName || 'Applicant',
      email: candidate.email || a.candidateEmail || '',
      phone: candidate.phone || a.candidatePhone || '',
      location: candidate.location || '', qualification: candidate.qualification || a.education || '',
      educationLevel: candidate.educationLevel || '',
      experienceYears: candidate.experienceYears || a.experienceYears || '',
      experienceMonths: candidate.experienceMonths || '',
      preferredJobTitles: candidate.preferredJobTitles || [],
      resumeFileName: candidate.resumeFileName || null,
      profilePhotoUrl: candidate.profilePhotoUrl || null,
    } });
  } catch (error) { return handleError(res, error); }
});

employerRouter.get('/applications/:applicationId/resume', verifyFirebaseToken, verified, async (req, res) => {
  try {
    await approvedEmployer(req.user.uid);
    const database = db();
    const application = await requireUnlocked(database, req.user.uid, req.params.applicationId);
    const candidate = await database.collection('candidates').doc(application.data().candidateUid).get();
    const publicId = candidate.data()?.resumePublicId;
    if (typeof publicId !== 'string' || !publicId.startsWith(`candidate_resumes/${application.data().candidateUid}/`)) {
      return res.status(404).json({ error: { message: 'No resume is available for this applicant.' } });
    }
    if (!process.env.CLOUDINARY_CLOUD_NAME || !process.env.CLOUDINARY_API_KEY || !process.env.CLOUDINARY_API_SECRET) {
      return res.status(503).json({ error: { message: 'Resume access is unavailable.' } });
    }
    cloudinary.config({
      cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
      api_key: process.env.CLOUDINARY_API_KEY,
      api_secret: process.env.CLOUDINARY_API_SECRET,
      secure: true,
    });
    const url = cloudinary.utils.private_download_url(publicId, 'pdf', {
      resource_type: 'raw', type: 'authenticated', expires_at: Math.floor(Date.now() / 1000) + 300,
    });
    return res.json({ url, expiresInSeconds: 300 });
  } catch (error) { return handleError(res, error); }
});

employerRouter.get('/admin/employers', verifyAdminToken, requireAdmin, async (req, res) => {
  try {
    const status = ['pending', 'approved', 'rejected'].includes(req.query.status) ? req.query.status : 'pending';
    const snapshot = await db().collection('employers').where('status', '==', status).limit(50).get();
    return res.json({ employers: snapshot.docs.map((doc) => ({ uid: doc.id, ...doc.data() })) });
  } catch (error) { return handleError(res, error); }
});

employerRouter.post('/admin/employers/:uid/decision', verifyAdminToken, requireAdmin, async (req, res) => {
  try {
    const decision = req.body?.decision;
    if (!['approved', 'rejected'].includes(decision)) return res.status(400).json({ error: { message: 'Choose approved or rejected.' } });
    const employerRef = db().collection('employers').doc(req.params.uid);
    const employer = await employerRef.get();
    if (!employer.exists) return res.status(404).json({ error: { message: 'Employer not found.' } });
    if (employer.data().status === decision &&
        (decision !== 'approved' || hasTrustedApproval(employer.data()))) {
      return res.json({ status: decision, unchanged: true });
    }
    if (decision === 'approved') {
      const identity = await auth.getUser(req.params.uid);
      if (!identity.emailVerified ||
          identity.email?.toLowerCase() !== employer.data().email?.toLowerCase()) {
        return res.status(409).json({ error: { message: 'The verified login email must match the company profile.' } });
      }
    }
    const batch = db().batch();
    batch.update(employerRef, {
      status: decision,
      reviewedAt: FieldValue.serverTimestamp(),
      reviewedBy: req.user.uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
    batch.create(db().collection('users').doc(req.params.uid).collection('notifications').doc(), {
      title: decision === 'approved' ? 'Company approved' : 'Company review update',
      body: decision === 'approved'
        ? 'Your company is approved. You can choose a posting plan and publish a job.'
        : 'Your company details need review. Contact Career360 support for help.',
      type: 'employer_review',
      createdAt: FieldValue.serverTimestamp(),
      readAt: null,
    });
    await batch.commit();
    if (decision === 'rejected') {
      const jobs = await db().collection('jobs').where('employerUid', '==', req.params.uid).get();
      const active = jobs.docs.filter((job) => job.data().status === 'active');
      for (let offset = 0; offset < active.length; offset += 400) {
        const closing = db().batch();
        for (const job of active.slice(offset, offset + 400)) {
          closing.update(job.ref, { status: 'closed', closedAt: FieldValue.serverTimestamp() });
        }
        await closing.commit();
      }
    }
    return res.json({ status: decision });
  } catch (error) { return handleError(res, error); }
});
