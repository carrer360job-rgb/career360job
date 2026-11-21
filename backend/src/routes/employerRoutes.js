import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { verifySupabaseToken, verifySensitiveToken, verifyAdminToken } from '../middlewares/authMiddleware.js';
import { requireAdmin } from '../middlewares/adminMiddleware.js';
import { listPublishedPlans, publishedPlan } from '../services/planCatalog.js';
import { sendNotificationToUser } from '../services/fcmService.js';

export const employerRouter = express.Router();
export const employerWebhookRouter = express.Router();

const applicationStatuses = new Map([
  ['Shortlisted', 'SHORTLISTED'], ['Interview', 'INTERVIEW'],
  ['Rejected', 'REJECTED'], ['Hired', 'HIRED'],
]);

const fail = (message, status = 400) => Object.assign(new Error(message), { status });

function handleError(res, error) {
  console.error('[Employer API]', error);
  return res.status(error.status || 500).json({
    error: { message: error.status ? error.message : 'Could not complete this request.' },
  });
}

function checked(result, message = 'Database is temporarily unavailable.') {
  if (result.error) throw fail(message, 503);
  return result.data;
}

function verified(req, res, next) {
  if (req.user.email_verified === true) return next();
  return res.status(403).json({ error: { message: 'Verify your email before continuing.' } });
}

export function hasTrustedApproval(profile) {
  return profile?.review_state === 'approved' && profile?.is_verified === true &&
    Boolean(profile.reviewed_by) && Boolean(profile.reviewed_at);
}

async function approvedEmployer(uid) {
  const [accountResult, employerResult] = await Promise.all([
    supabaseAdmin.from('profiles').select('role,status').eq('id', uid).maybeSingle(),
    supabaseAdmin.from('employers').select('*').eq('user_id', uid).maybeSingle(),
  ]);
  const account = checked(accountResult);
  const employer = checked(employerResult);
  if (account?.role !== 'EMPLOYER' || account.status !== 'ACTIVE' || !hasTrustedApproval(employer)) {
    throw fail('Your company must be approved before this action.', 403);
  }
  return employer;
}

function paymentReady() {
  const id = process.env.RAZORPAY_KEY_ID || '';
  return Boolean(id && process.env.RAZORPAY_KEY_SECRET && process.env.RAZORPAY_WEBHOOK_SECRET &&
    (id.startsWith('rzp_test_') || (id.startsWith('rzp_live_') && process.env.RAZORPAY_ENABLE_LIVE === 'true')));
}

function safeString(value, max, min = 1) {
  if (typeof value !== 'string') return null;
  const text = value.trim();
  return text.length >= min && text.length <= max ? text : null;
}

function jobFields(body = {}) {
  const title = safeString(body.title, 100, 3);
  const description = safeString(body.description, 5000, 30);
  const salaryText = safeString(body.salaryText, 80, 3);
  const district = safeString(body.district, 80, 2);
  const category = safeString(body.category, 80, 2);
  const workMode = safeString(body.workMode, 20, 2);
  const vacanciesCount = Number(body.vacanciesCount);
  if (!title || !description || !salaryText || !district || !category ||
      !['On-site', 'Hybrid', 'Remote'].includes(workMode) ||
      !Number.isInteger(vacanciesCount) || vacanciesCount < 1 || vacanciesCount > 999) {
    throw fail('Enter valid job details before publishing.');
  }
  return {
    title, description, salaryText, district, category, workMode, vacanciesCount,
    contactName: safeString(body.contactName, 80, 2),
    phone: safeString(body.phone, 20, 7),
    whatsappNumber: safeString(body.whatsappNumber, 20, 7),
    email: safeString(body.email, 120, 5),
    isStatewide: body.isStatewide !== false,
  };
}

export async function razorpayRequest(path, options = {}) {
  const key = Buffer.from(`${process.env.RAZORPAY_KEY_ID}:${process.env.RAZORPAY_KEY_SECRET}`).toString('base64');
  const response = await fetch(`https://api.razorpay.com/v1${path}`, {
    ...options,
    headers: { Authorization: `Basic ${key}`, 'Content-Type': 'application/json', ...options.headers },
    signal: AbortSignal.timeout(12000),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error('[Razorpay]', response.status, data.error?.code || 'unknown');
    throw fail('Payment service is unavailable. Try again later.', 502);
  }
  return data;
}

export function signaturesMatch(message, signature, secret) {
  if (typeof signature !== 'string' || !/^[0-9a-f]{64}$/i.test(signature)) return false;
  const expected = createHmac('sha256', secret).update(message).digest();
  return timingSafeEqual(expected, Buffer.from(signature, 'hex'));
}

async function grantCredits(orderId, payment) {
  if (payment.order_id !== orderId || payment.status !== 'captured' ||
      !payment.id || !Number.isInteger(payment.amount) || payment.currency !== 'INR') {
    throw fail('Payment details do not match the order.');
  }
  return checked(await supabaseAdmin.rpc('fulfill_employer_order', {
    p_order_id: orderId, p_payment_id: payment.id,
    p_amount: payment.amount, p_currency: payment.currency,
    p_amount_refunded: payment.amount_refunded || 0,
  }), 'Payment could not be fulfilled. Contact support.');
}

export async function revokeFullyRefundedOrder(payment) {
  if (!payment?.order_id || !payment?.id || payment.amount <= 0 ||
      payment.amount_refunded < payment.amount) return false;
  return checked(await supabaseAdmin.rpc('refund_employer_order', {
    p_order_id: payment.order_id, p_payment_id: payment.id,
    p_amount: payment.amount, p_currency: payment.currency,
  }), 'Refund could not be recorded.');
}

employerRouter.get('/me', verifySupabaseToken, async (req, res) => {
  try {
    if (req.user.role !== 'EMPLOYER') throw fail('Employer account required.', 403);
    const employer = checked(await supabaseAdmin.from('employers')
      .select('id,company_name,is_verified,posting_credits')
      .eq('user_id', req.user.uid).maybeSingle());
    if (!employer) throw fail('Employer profile not found.', 404);
    res.set('Cache-Control', 'no-store');
    return res.json({ employer });
  } catch (error) { return handleError(res, error); }
});

employerRouter.get('/plans', async (_req, res) => {
  try {
    res.set('Cache-Control', 'no-store');
    return res.json({ plans: await listPublishedPlans(), checkoutReady: paymentReady() });
  } catch (error) { return handleError(res, error); }
});

employerRouter.post('/orders', verifySensitiveToken, verified, async (req, res) => {
  try {
    const employer = await approvedEmployer(req.user.uid);
    const planId = req.body?.planId;
    if (typeof planId !== 'string') throw fail('Choose a plan.');
    const plan = await publishedPlan(planId);
    if (req.body?.planVersion !== plan.version) throw fail('This plan has changed. Refresh plans before checkout.', 409);
    if (plan.amountPaise < 100 || !['monthly', 'quarterly', 'yearly'].includes(plan.tier)) {
      throw fail('Choose a paid plan.', 409);
    }
    if (!paymentReady()) throw fail('Payments are not configured yet.', 503);
    const created = await razorpayRequest('/orders', {
      method: 'POST',
      body: JSON.stringify({ amount: plan.amountPaise, currency: 'INR',
        receipt: `c360_${randomUUID().replaceAll('-', '').slice(0, 30)}`,
        notes: { employerUid: req.user.uid, planId: plan.id } }),
    });
    if (!created.id || created.amount !== plan.amountPaise || created.currency !== 'INR') {
      throw fail('Payment order could not be confirmed.', 502);
    }
    checked(await supabaseAdmin.from('employer_orders').insert({
      id: created.id, employer_id: employer.id, employer_user_id: req.user.uid,
      plan_id: plan.id, plan_version: plan.version, plan_name: plan.name,
      tier: plan.tier, amount_paise: plan.amountPaise,
      base_paise: plan.basePaise, tax_paise: plan.taxPaise, currency: 'INR',
      tax_mode: plan.taxMode, tax_rate_bps: plan.taxRateBps,
      job_credits: plan.jobCredits, listing_days: plan.listingDays,
      credit_validity_days: plan.creditValidityDays,
      profile_unlock_limit: plan.profileUnlockLimit, reach: plan.reach,
    }), 'Payment order could not be saved. Please try again.');
    return res.json({ orderId: created.id, keyId: process.env.RAZORPAY_KEY_ID,
      amountPaise: plan.amountPaise, basePaise: plan.basePaise,
      taxPaise: plan.taxPaise, planVersion: plan.version, currency: 'INR' });
  } catch (error) { return handleError(res, error); }
});

employerRouter.post('/orders/verify', verifySensitiveToken, verified, async (req, res) => {
  try {
    if (!paymentReady()) throw fail('Payments are unavailable.', 503);
    const orderId = safeString(req.body?.orderId, 80);
    const paymentId = safeString(req.body?.paymentId, 80);
    if (!orderId || !paymentId || !signaturesMatch(
      `${orderId}|${paymentId}`, req.body?.signature, process.env.RAZORPAY_KEY_SECRET)) {
      throw fail('Payment verification failed.');
    }
    const order = checked(await supabaseAdmin.from('employer_orders')
      .select('employer_user_id').eq('id', orderId).maybeSingle());
    if (order?.employer_user_id !== req.user.uid) throw fail('This order belongs to another account.', 403);
    const payment = await razorpayRequest(`/payments/${encodeURIComponent(paymentId)}`);
    if (payment.amount_refunded >= payment.amount) {
      await revokeFullyRefundedOrder(payment);
      throw fail('This payment was refunded.', 409);
    }
    const result = await grantCredits(orderId, payment);
    return res.json({ status: 'paid', ...result });
  } catch (error) { return handleError(res, error); }
});

employerRouter.post('/orders/failure', verifySensitiveToken, verified, async (req, res) => {
  try {
    const orderId = safeString(req.body?.orderId, 80);
    if (!orderId) throw fail('Payment order is required.');
    const order = checked(await supabaseAdmin.from('employer_orders')
      .select('employer_user_id').eq('id', orderId).maybeSingle());
    if (order?.employer_user_id !== req.user.uid) throw fail('This order belongs to another account.', 403);
    checked(await supabaseAdmin.from('employer_orders').update({
      status: 'failed', failure_code: safeString(req.body?.code, 80) || 'payment_not_completed',
      failed_at: new Date().toISOString(),
    }).eq('id', orderId).eq('status', 'created'));
    return res.json({ status: 'recorded' });
  } catch (error) { return handleError(res, error); }
});

employerWebhookRouter.post('/', express.raw({ type: 'application/json', limit: '256kb' }), async (req, res) => {
  try {
    const secret = process.env.RAZORPAY_WEBHOOK_SECRET;
    if (!secret || !Buffer.isBuffer(req.body) ||
        !signaturesMatch(req.body, req.header('x-razorpay-signature'), secret)) {
      return res.status(401).end();
    }
    const event = JSON.parse(req.body.toString('utf8'));
    if (event.event === 'payment.captured') {
      const paymentId = event.payload?.payment?.entity?.id;
      if (paymentId) {
        const payment = await razorpayRequest(`/payments/${encodeURIComponent(paymentId)}`);
        if (payment.amount_refunded >= payment.amount) await revokeFullyRefundedOrder(payment);
        else await grantCredits(payment.order_id, payment);
      }
    } else if (event.event === 'refund.processed' || event.event === 'payment.refunded') {
      const paymentId = event.event === 'refund.processed'
        ? event.payload?.refund?.entity?.payment_id : event.payload?.payment?.entity?.id;
      if (paymentId) {
        const payment = await razorpayRequest(`/payments/${encodeURIComponent(paymentId)}`);
        await revokeFullyRefundedOrder(payment);
      }
    }
    return res.json({ received: true });
  } catch (error) { return handleError(res, error); }
});

employerRouter.post('/jobs', verifySupabaseToken, verified, async (req, res) => {
  try {
    await approvedEmployer(req.user.uid);
    const fields = jobFields(req.body);
    const jobId = checked(await supabaseAdmin.rpc('submit_employer_job', {
      p_user_id: req.user.uid, p_job: fields,
    }), 'Job could not be submitted. Check your plan and try again.');
    return res.status(201).json({ jobId, status: 'pending_review' });
  } catch (error) { return handleError(res, error); }
});

employerRouter.post('/jobs/:jobId/report', verifySensitiveToken, verified, async (req, res) => {
  try {
    if (req.user.role !== 'CANDIDATE') throw fail('Only job seekers can report a listing.', 403);
    const reason = ['fraud', 'misleading', 'duplicate', 'inappropriate', 'other'].includes(req.body?.reason)
      ? req.body.reason : null;
    const details = typeof req.body?.details === 'string' ? req.body.details.trim().slice(0, 500) : '';
    if (!reason || (reason === 'other' && details.length < 5)) throw fail('Choose a report reason and add details when selecting Other.');
    const job = checked(await supabaseAdmin.from('jobs').select('id')
      .eq('id', req.params.jobId).maybeSingle());
    if (!job) throw fail('Job not found.', 404);
    const result = await supabaseAdmin.from('job_reports').insert({
      job_id: job.id, candidate_user_id: req.user.uid, reason, details,
    });
    if (result.error?.code === '23505') throw fail('You have already reported this job.', 409);
    checked(result);
    return res.status(201).json({ status: 'submitted' });
  } catch (error) { return handleError(res, error); }
});

async function ownedJob(uid, jobId) {
  const employer = await approvedEmployer(uid);
  const job = checked(await supabaseAdmin.from('jobs').select('id,status,reach')
    .eq('id', jobId).eq('employer_id', employer.id).maybeSingle());
  if (!job) throw fail('Job not found.', 404);
  return job;
}

employerRouter.patch('/jobs/:jobId', verifySupabaseToken, verified, async (req, res) => {
  try {
    const job = await ownedJob(req.user.uid, req.params.jobId);
    if (job.status !== 'PENDING_REVIEW') throw fail('Only jobs awaiting review can be edited. Submit a new job for changed details.', 409);
    const fields = jobFields(req.body);
    if (fields.district === 'All Tamil Nadu' && job.reach !== 'statewide') {
      throw fail('Choose a district for this plan.', 400);
    }
    checked(await supabaseAdmin.from('jobs').update({
      title: fields.title, description: fields.description,
      salary_text: fields.salaryText, district: fields.district,
      category: fields.category, work_mode: fields.workMode,
      vacancies: fields.vacanciesCount, contact_name: fields.contactName,
      contact_phone: fields.phone || undefined,
      contact_whatsapp: fields.whatsappNumber,
      contact_email: fields.email, updated_at: new Date().toISOString(),
    }).eq('id', job.id).eq('status', 'PENDING_REVIEW'));
    return res.json({ jobId: job.id });
  } catch (error) { return handleError(res, error); }
});

employerRouter.post('/jobs/:jobId/close', verifySupabaseToken, verified, async (req, res) => {
  try {
    const job = await ownedJob(req.user.uid, req.params.jobId);
    if (job.status === 'PUBLISHED') checked(await supabaseAdmin.from('jobs')
      .update({ status: 'CLOSED', updated_at: new Date().toISOString() }).eq('id', job.id));
    return res.json({ status: 'closed' });
  } catch (error) { return handleError(res, error); }
});

async function ownedApplication(uid, applicationId) {
  const employer = await approvedEmployer(uid);
  const application = checked(await supabaseAdmin.from('job_applications')
    .select('*')
    .eq('id', applicationId).eq('employer_id', employer.id).maybeSingle());
  if (!application) throw fail('Application not found.', 404);
  return { employer, application };
}

employerRouter.patch('/applications/:applicationId/status', verifySupabaseToken, verified, async (req, res) => {
  try {
    const status = applicationStatuses.get(req.body?.status);
    if (!status) throw fail('Choose a valid application status.');
    const { application } = await ownedApplication(req.user.uid, req.params.applicationId);
    if (application.status !== status) {
      checked(await supabaseAdmin.from('job_applications').update({
        status, updated_at: new Date().toISOString(),
      }).eq('id', application.id));
      const candidate = checked(await supabaseAdmin.from('candidate_profiles')
        .select('user_id').eq('id', application.candidate_id).maybeSingle());
      const job = checked(await supabaseAdmin.from('jobs').select('title')
        .eq('id', application.job_id).maybeSingle());
      if (candidate?.user_id) {
        const title = job?.title || 'a job';
      const notice = await supabaseAdmin.from('notifications').insert({
          user_id: candidate.user_id, title: 'Application update',
          message: `Your application for ${title} is now ${status.toLowerCase()}.`,
          type: 'application_status',
        });
      if (notice.error) console.warn('[Application notification]', notice.error.message);
        sendNotificationToUser({ userId: candidate.user_id,
          title: 'Application Update',
          body: `Your application for ${title} is now ${status.toLowerCase()}.`,
          type: 'application_status',
          metadata: { jobId: application.job_id, applicationId: application.id },
        }).catch((error) => console.warn('[FCM Push Notice]', error.message));
      }
    }
    return res.json({ status: req.body.status });
  } catch (error) { return handleError(res, error); }
});

employerRouter.get('/entitlement', verifySupabaseToken, verified, async (req, res) => {
  try {
    const employer = await approvedEmployer(req.user.uid);
    const [row, subscription] = await Promise.all([
      supabaseAdmin.from('employer_entitlements').select('*').eq('employer_id', employer.id).maybeSingle(),
      supabaseAdmin.from('employer_subscriptions').select('*').eq('employer_id', employer.id).eq('status', 'active').maybeSingle(),
    ]);
    if (row.error || subscription.error) throw fail('Subscription details are unavailable.', 503);
    res.set('Cache-Control', 'no-store');
    return res.json({ entitlement: row.data ? {
      planId: row.data.plan_id, planName: row.data.plan_name, tier: row.data.tier,
      reach: row.data.reach, profileUnlockLimit: row.data.profile_unlock_limit,
      unlocksUsed: row.data.unlocks_used, startsAt: row.data.starts_at,
      expiresAt: row.data.expires_at, active: Date.parse(row.data.expires_at) > Date.now(),
      totalPosts: subscription.data?.total_posts ?? null,
      usedPosts: subscription.data?.used_posts ?? null,
      remainingPosts: subscription.data ? subscription.data.total_posts - subscription.data.used_posts : null,
    } : null });
  } catch (error) { return handleError(res, error); }
});

employerRouter.get('/applications', verifySupabaseToken, verified, async (req, res) => {
  try {
    const employer = await approvedEmployer(req.user.uid);
    const offset = Number(req.query.offset ?? 0);
    if (!Number.isSafeInteger(offset) || offset < 0) throw fail('Choose a valid applications page.');
    const pageSize = 200;
    const [appsResult, jobsResult, entitlementResult] = await Promise.all([
      supabaseAdmin.from('job_applications').select('*', { count: 'exact' }).eq('employer_id', employer.id)
        .order('created_at', { ascending: false }).order('id', { ascending: false })
        .range(offset, offset + pageSize - 1),
      supabaseAdmin.from('jobs').select('id,title').eq('employer_id', employer.id),
      supabaseAdmin.from('employer_entitlements').select('*').eq('employer_id', employer.id).maybeSingle(),
    ]);
    const apps = checked(appsResult);
    const jobs = checked(jobsResult);
    const entitlement = checked(entitlementResult);
    const active = entitlement && Date.parse(entitlement.expires_at) > Date.now();
    const unlocks = active ? checked(await supabaseAdmin.from('employer_candidate_unlocks')
      .select('candidate_id').eq('employer_id', employer.id).eq('order_id', entitlement.order_id)) : [];
    const unlockedIds = new Set(unlocks.map((row) => row.candidate_id));
    const titles = new Map(jobs.map((job) => [job.id, job.title]));
    const applications = apps.map((app) => ({
      id: app.id, candidateName: app.applicant_name || 'Applicant',
      jobId: app.job_id, jobTitle: titles.get(app.job_id) || 'Job',
      education: app.education_details || '', experienceYears: app.experience_level || '',
      noticePeriod: app.notice_period || '', skills: app.skills || [],
      coverNote: app.cover_note || '', hasResume: Boolean(app.resume_url),
      status: !app.status || app.status === 'SUBMITTED' ? 'Applied' :
        app.status.charAt(0) + app.status.slice(1).toLowerCase(),
      appliedAt: app.created_at, createdAt: app.created_at,
      district: app.applicant_district || '', unlocked: unlockedIds.has(app.candidate_id),
    }));
    res.set('Cache-Control', 'no-store');
    return res.json({ applications, totalApplications: appsResult.count ?? offset + apps.length,
      hasMore: appsResult.count == null ? apps.length === pageSize
        : offset + apps.length < appsResult.count,
      remainingUnlocks: active
        ? Math.max(0, entitlement.profile_unlock_limit - entitlement.unlocks_used) : 0 });
  } catch (error) { return handleError(res, error); }
});

employerRouter.post('/applications/:applicationId/view', verifySensitiveToken, verified, async (req, res) => {
  try {
    const { employer, application } = await ownedApplication(req.user.uid, req.params.applicationId);
    const entitlement = checked(await supabaseAdmin.from('employer_entitlements')
      .select('order_id,expires_at').eq('employer_id', employer.id).maybeSingle());
    if (!entitlement || Date.parse(entitlement.expires_at) <= Date.now()) {
      throw fail('Choose an active hiring plan to view applicant details.', 402);
    }
    const candidate = checked(await supabaseAdmin.from('candidate_profiles').select('*')
      .eq('id', application.candidate_id).maybeSingle());
    if (!candidate) throw fail('Applicant profile not found.', 404);
    const account = checked(await supabaseAdmin.from('profiles').select('email,phone')
      .eq('id', candidate.user_id).maybeSingle());
    const education = candidate.education || {};
    const experience = candidate.experience || {};
    const job = checked(await supabaseAdmin.from('jobs').select('title')
      .eq('id', application.job_id).maybeSingle());
    let resumeUrl = null;
    if (application.resume_url) {
      const signed = checked(await supabaseAdmin.storage.from('resumes')
        .createSignedUrl(application.resume_url, 600), 'Resume is temporarily unavailable.');
      resumeUrl = signed.signedUrl;
    }
    const unlockResult = await supabaseAdmin.rpc('unlock_employer_candidate', {
      p_user_id: req.user.uid, p_application_id: application.id,
    });
    if (unlockResult.error) {
      if (/no profile unlocks remaining|active plan/i.test(unlockResult.error.message)) {
        throw fail('Your plan has reached its applicant profile viewing limit. Choose a hiring plan to continue.', 402);
      }
      throw fail('Applicant details are temporarily unavailable. Try again.', 503);
    }
    res.set('Cache-Control', 'no-store');
    return res.json({ alreadyUnlocked: unlockResult.data?.alreadyUnlocked === true, profile: {
      name: application.applicant_name || candidate.full_name,
      email: application.applicant_email || account?.email || '',
      phone: application.applicant_phone || account?.phone || '',
      location: application.applicant_district || candidate.district || '',
      qualification: application.education_details || education.qualification || '',
      educationLevel: education.educationLevel || '',
      experienceYears: application.experience_level || experience.experienceYears || '',
      noticePeriod: application.notice_period || '', skills: application.skills || [],
      coverNote: application.cover_note || '',
      resumeFileName: application.resume_file_name || application.resume_url?.split('/').pop() || '', resumeUrl,
      experienceMonths: experience.experienceMonths || '',
      preferredJobTitles: candidate.preferred_job_titles || [],
      profilePhotoUrl: candidate.profile_photo_url || null,
      application: {
        jobTitle: job?.title || 'Job', status: application.status || 'SUBMITTED',
        appliedAt: application.created_at || null,
        name: application.applicant_name || '', email: application.applicant_email || '',
        phone: application.applicant_phone || '', district: application.applicant_district || '',
        qualification: application.education_details || '',
        experienceLevel: application.experience_level || '',
        noticePeriod: application.notice_period || '', skills: application.skills || [],
        coverNote: application.cover_note || '',
      },
      candidateProfile: {
        educationLevel: education.educationLevel || '', qualification: education.qualification || '',
        collegeOrSchool: education.collegeOrSchool || '', graduationYear: education.graduationYear || '',
        hasExperience: typeof experience.hasExperience === 'boolean' ? experience.hasExperience : null,
        experienceYears: experience.experienceYears || '', experienceMonths: experience.experienceMonths || '',
        lastCompany: experience.lastCompany || '', lastJobTitle: experience.lastJobTitle || '',
        noticePeriod: experience.noticePeriod || '',
        preferredJobTitles: candidate.preferred_job_titles || [],
        district: candidate.district || '',
      },
    } });
  } catch (error) { return handleError(res, error); }
});

employerRouter.get('/admin/employers', verifyAdminToken, requireAdmin, async (req, res) => {
  try {
    const verified = req.query.status === 'approved';
    const rows = checked(await supabaseAdmin.from('employers').select('*')
      .eq('is_verified', verified).limit(50));
    return res.json({ employers: rows.map((row) => ({ uid: row.user_id, ...row })) });
  } catch (error) { return handleError(res, error); }
});

employerRouter.post('/admin/employers/:uid/decision', verifyAdminToken, requireAdmin, async (req, res) => {
  try {
    const decision = req.body?.decision;
    if (!['approved', 'rejected'].includes(decision)) throw fail('Choose approved or rejected.');
    if (decision === 'approved') {
      const [identityResult, companyResult] = await Promise.all([
        supabaseAdmin.auth.admin.getUserById(req.params.uid),
        supabaseAdmin.from('employers').select('email').eq('user_id', req.params.uid).maybeSingle(),
      ]);
      if (identityResult.error || companyResult.error) throw fail('Employer identity could not be checked.', 503);
      if (!companyResult.data) throw fail('Employer account not found.', 404);
      const identity = identityResult.data?.user;
      if (!identity?.email_confirmed_at ||
          identity.email?.toLowerCase() !== companyResult.data.email?.toLowerCase()) {
        throw fail('The verified login email must match the company profile.', 409);
      }
    }
    const result = checked(await supabaseAdmin.rpc('admin_review_employer', {
      p_actor_uid: req.user.uid, p_employer_uid: req.params.uid,
      p_decision: decision, p_notes: req.body?.notes || null,
    }), 'Employer review could not be saved.');
    return res.json(result);
  } catch (error) { return handleError(res, error); }
});
