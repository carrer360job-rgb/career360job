import express from 'express';
import { verifyAdminToken } from '../middlewares/authMiddleware.js';
import { requireAdmin } from '../middlewares/adminMiddleware.js';
import { supabaseAdmin } from '../config/supabase.js';
import adminSupabaseModules from './adminSupabaseModules.js';
import { razorpayRequest, revokeFullyRefundedOrder } from './employerRoutes.js';
import { sendNotificationToUser } from '../services/fcmService.js';

const router = express.Router();

router.get('/me', verifyAdminToken, requireAdmin, (req, res) => {
  res.set('Cache-Control', 'no-store');
  res.json({
    uid: req.user.uid,
    email: req.user.email,
    role: 'admin',
  });
});

router.use(verifyAdminToken, requireAdmin);

function fail(res, error) {
  console.error('[Admin API]', error);
  return res.status(error.status || 500).json({ error: { message: error.status ? error.message : 'Admin request failed.' } });
}

async function countRows(table, filter) {
  let query = supabaseAdmin.from(table).select('id', { count: 'exact', head: true });
  if (filter) query = filter(query);
  const { count, error } = await query;
  if (error) {
    console.error('[Admin stats count]', table, error);
    throw Object.assign(new Error('Platform metrics are temporarily unavailable.'), { status: 503 });
  }
  return count ?? 0;
}

function employerStatus(reviewState, accountStatus) {
  if (reviewState === 'rejected') return 'rejected';
  if (reviewState === 'suspended' || ['SUSPENDED', 'BLOCKED'].includes(accountStatus)) return 'suspended';
  if (reviewState === 'approved' && accountStatus === 'ACTIVE') return 'approved';
  return 'pending';
}

// 1. Platform Statistics Dashboard
router.get('/stats', async (req, res) => {
  try {
    const [totalCandidates, totalEmployers, pendingEmployers, approvedEmployers, rejectedEmployers,
      totalJobs, activeJobs, closedJobs, totalApplications] = await Promise.all([
      countRows('profiles', (query) => query.eq('role', 'CANDIDATE')),
      countRows('employers'),
      countRows('employers', (query) => query.eq('is_verified', false)),
      countRows('employers', (query) => query.eq('is_verified', true)),
      countRows('profiles', (query) => query.eq('role', 'EMPLOYER').in('status', ['SUSPENDED', 'BLOCKED'])),
      countRows('jobs'),
      countRows('jobs', (query) => query.eq('status', 'PUBLISHED')),
      countRows('jobs', (query) => query.eq('status', 'CLOSED')),
      countRows('job_applications'),
    ]);

    res.set('Cache-Control', 'no-store');
    res.json({
      totalCandidates,
      totalEmployers,
      pendingEmployers: Math.max(0, pendingEmployers - rejectedEmployers),
      approvedEmployers: Math.max(0, approvedEmployers - rejectedEmployers),
      rejectedEmployers,
      totalJobs,
      activeJobs,
      closedJobs,
      totalApplications,
    });
  } catch (error) {
    fail(res, error);
  }
});

// 2. Employers List with Filtering
router.get('/employers', async (req, res) => {
  try {
    const statusFilter = ['pending', 'approved', 'rejected'].includes(req.query.status) ? req.query.status : 'all';
    const search = typeof req.query.search === 'string' ? req.query.search.trim().toLowerCase() : '';
    const offset = req.query.cursor === undefined ? 0 : Number(req.query.cursor);
    if (!Number.isSafeInteger(offset) || offset < 0) {
      return res.status(400).json({ error: { message: 'Invalid employer page cursor.' } });
    }
    // Scan until a full page of matching companies is found. Filtering after
    // only the first database page hides matches on later pages.
    const employers = [];
    let scanOffset = offset;
    let hasMore = true;
    while (employers.length < 50 && hasMore) {
      const batchSize = 50 - employers.length;
      const { data: rows, error } = await supabaseAdmin.from('employers')
        .select('user_id,company_name,contact_name,designation,email,phone,whatsapp_phone,industry,company_size,state,district,address,postal_code,posting_credits,active_plan,is_verified,review_state,created_at,reviewed_by,reviewed_at,rejection_reason')
        .order('created_at', { ascending: false }).order('user_id', { ascending: false })
        .range(scanOffset, scanOffset + batchSize - 1);
      if (error) throw Object.assign(new Error('Employer directory is unavailable.'), { status: 503 });
      const pageRows = rows || [];
      scanOffset += pageRows.length;
      hasMore = pageRows.length === batchSize;
      if (!pageRows.length) break;
      const userIds = pageRows.map((row) => row.user_id).filter(Boolean);
      const { data: profiles, error: profilesError } = userIds.length
        ? await supabaseAdmin.from('profiles').select('id,status').in('id', userIds)
        : { data: [], error: null };
      if (profilesError) throw Object.assign(new Error('Employer account status is unavailable.'), { status: 503 });
      const profileStatus = new Map((profiles || []).map((profile) => [profile.id, profile.status]));
      const candidates = pageRows.map((row) => ({
        uid: row.user_id, companyName: row.company_name || '', contactName: row.contact_name || '',
        designation: row.designation || '', email: row.email || '', phone: row.phone || '',
        whatsappPhone: row.whatsapp_phone || row.phone || '', industry: row.industry || '',
        companySize: row.company_size || '', state: row.state || '', district: row.district || '',
        address: row.address || '', postalCode: row.postal_code || '', registrationNumber: '',
        status: employerStatus(row.review_state, profileStatus.get(row.user_id)),
        postingCredits: row.posting_credits || 0, activePlan: row.active_plan || '',
        rejectionReason: row.rejection_reason || null, reviewedBy: row.reviewed_by || null,
        reviewedAt: row.reviewed_at || null, createdAt: row.created_at || null,
      }));
      employers.push(...candidates.filter((employer) =>
        (statusFilter === 'all' || (statusFilter === 'rejected'
          ? ['rejected', 'suspended'].includes(employer.status) : employer.status === statusFilter)) &&
        (!search || [employer.companyName, employer.contactName, employer.email,
          employer.phone, employer.district].some((field) => field.toLowerCase().includes(search)))));
    }
    res.set('Cache-Control', 'no-store');
    res.json({ employers, nextCursor: hasMore ? String(scanOffset) : null });
  } catch (error) {
    fail(res, error);
  }
});

router.get('/employers/:uid', async (req, res) => {
  try {
    const { uid } = req.params;
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(uid)) {
      return res.status(400).json({ error: { message: 'Invalid employer ID.' } });
    }
    const [companyResult, profileResult, identityResult] = await Promise.all([
      supabaseAdmin.from('employers').select('*').eq('user_id', uid).maybeSingle(),
      supabaseAdmin.from('profiles').select('id,role,status,email,phone,created_at').eq('id', uid).maybeSingle(),
      supabaseAdmin.auth.admin.getUserById(uid),
    ]);
    if (companyResult.error || profileResult.error || identityResult.error) {
      throw Object.assign(new Error('Employer profile is unavailable.'), { status: 503 });
    }
    const company = companyResult.data;
    const profile = profileResult.data;
    const identity = identityResult.data?.user;
    if (!company || !profile || profile.role !== 'EMPLOYER' || !identity) {
      return res.status(404).json({ error: { message: 'Employer account not found.' } });
    }
    const [subscriptionResult, ordersResult] = await Promise.all([
      supabaseAdmin.from('employer_subscriptions').select('id,plan_name,total_posts,used_posts,starts_at,expires_at,status,order_id')
        .eq('employer_id', company.id).order('created_at', { ascending: false }).limit(25),
      supabaseAdmin.from('employer_orders').select('id,plan_name,amount_paise,tax_paise,status,created_at,paid_at')
        .eq('employer_id', company.id).order('created_at', { ascending: false }).limit(25),
    ]);
    if (subscriptionResult.error || ordersResult.error) {
      throw Object.assign(new Error('Employer billing history is unavailable.'), { status: 503 });
    }
    const status = employerStatus(company.review_state, profile.status);
    res.set('Cache-Control', 'no-store');
    res.json({ employer: {
      uid, companyName: company.company_name || '', logoUrl: company.logo_url || '',
      contactName: company.contact_name || '', designation: company.designation || '',
      email: company.email || profile.email || '', phone: company.phone || profile.phone || '',
      whatsappPhone: company.whatsapp_phone || '', whatsappSameAsPhone: company.whatsapp_same_as_phone === true,
      industry: company.industry || '', companySize: company.company_size || '',
      website: company.website || '', description: company.description || '',
      address: company.address || '', city: company.city || '', state: company.state || '',
      district: company.district || '', postalCode: company.postal_code || '',
      registrationNumber: company.registration_number || '', status,
      accountStatus: profile.status || '', emailVerified: Boolean(identity.email_confirmed_at),
      lastSignInAt: identity.last_sign_in_at || null,
      postingCredits: company.posting_credits || 0, activePlan: company.active_plan || '',
      activePlanName: company.active_plan_name || '', planTier: company.plan_tier || '',
      planReach: company.plan_reach || '', listingDays: company.listing_days || 0,
      creditsExpireAt: company.credits_expire_at || null,
      rejectionReason: company.rejection_reason || null, reviewedBy: company.reviewed_by || null,
      reviewedAt: company.reviewed_at || null, createdAt: company.created_at || profile.created_at || null,
      updatedAt: company.updated_at || null,
      subscriptions: (subscriptionResult.data || []).map((row) => ({
        ...row, status: row.status === 'active' && Date.parse(row.expires_at) <= Date.now()
          ? 'expired' : row.status,
      })), orders: ordersResult.data || [],
    } });
  } catch (error) {
    fail(res, error);
  }
});

router.post('/employers/:uid/quota', async (req, res) => {
  try {
    const uid = req.params.uid;
    const delta = req.body?.delta;
    const reason = typeof req.body?.reason === 'string' ? req.body.reason.trim() : '';
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(uid) ||
        !Number.isInteger(delta) || delta === 0 || Math.abs(delta) > 10000 ||
        reason.length < 5 || reason.length > 500) {
      return res.status(400).json({ error: { message: 'Enter a valid quota change and reason.' } });
    }
    const { data, error } = await supabaseAdmin.rpc('admin_adjust_employer_quota', {
      p_actor_uid: req.user.uid, p_employer_uid: uid, p_delta: delta, p_reason: reason,
    });
    if (error) {
      console.error('[Admin quota adjustment]', error);
      return res.status(409).json({ error: { message: error.message } });
    }
    res.set('Cache-Control', 'no-store').json(data);
  } catch (error) { fail(res, error); }
});

// 3. Employer Review (Approve / Reject)
router.post('/employers/:uid/review', async (req, res) => {
  try {
    const uid = req.params.uid;
    const { decision, notes } = req.body || {};
    if (!['approved', 'rejected'].includes(decision)) {
      return res.status(400).json({ error: { message: 'Decision must be "approved" or "rejected".' } });
    }
    const reason = typeof notes === 'string' ? notes.trim().slice(0, 500) : '';
    if (decision === 'rejected' && reason.length < 3) {
      return res.status(400).json({ error: { message: 'Enter a reason for rejecting or suspending this company.' } });
    }
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(uid)) {
      return res.status(400).json({ error: { message: 'Invalid employer ID.' } });
    }
    if (decision === 'approved') {
      const [identityResult, companyResult] = await Promise.all([
        supabaseAdmin.auth.admin.getUserById(uid),
        supabaseAdmin.from('employers').select('email').eq('user_id', uid).maybeSingle(),
      ]);
      if (identityResult.error || companyResult.error) {
        throw Object.assign(new Error('Employer identity could not be checked.'), { status: 503 });
      }
      if (!companyResult.data) {
        return res.status(404).json({ error: { message: 'Employer account not found.' } });
      }
      const identity = identityResult.data?.user;
      if (!identity?.email_confirmed_at ||
          identity.email?.toLowerCase() !== companyResult.data.email?.toLowerCase()) {
        return res.status(409).json({ error: { message: 'The verified login email must match the company profile.' } });
      }
    }
    const { data, error } = await supabaseAdmin.rpc('admin_review_employer', {
      p_actor_uid: req.user.uid, p_employer_uid: uid, p_decision: decision, p_notes: reason || null,
    });
    if (error) {
      if (error.message.includes('not found')) return res.status(404).json({ error: { message: 'Employer account not found.' } });
      console.error('[Admin employer review]', error);
      throw Object.assign(new Error('Employer review is unavailable.'), { status: 503 });
    }
    res.json(data);
  } catch (error) {
    fail(res, error);
  }
});

router.use(adminSupabaseModules);

router.get('/payments', async (req, res) => {
  try {
    const offset = req.query.cursor === undefined ? 0 : Number(req.query.cursor);
    if (!Number.isSafeInteger(offset) || offset < 0) {
      return res.status(400).json({ error: { message: 'Invalid page cursor.' } });
    }
    const status = ['created','failed','paid','refunded'].includes(req.query.status) ? req.query.status : 'all';
    let query = supabaseAdmin.from('employer_orders').select('*').order('created_at', { ascending: false });
    if (status !== 'all') query = query.eq('status', status);
    const { data, error } = await query.range(offset, offset + 49);
    if (error) throw Object.assign(new Error('Payments are unavailable.'), { status: 503 });
    const payments = (data || []).map((row) => ({
      id: row.id, employerUid: row.employer_user_id, planId: row.plan_id,
      planName: row.plan_name, amountPaise: row.amount_paise,
      basePaise: row.base_paise, taxPaise: row.tax_paise,
      taxMode: row.tax_mode || 'inclusive',
      taxRateBps: row.tax_rate_bps ?? (row.base_paise ? Math.round(row.tax_paise / row.base_paise * 10000) : 0),
      currency: row.currency, status: row.status, paymentId: row.payment_id,
      createdAt: row.created_at, paidAt: row.paid_at, refundedAt: row.refunded_at,
      failedAt: row.failed_at, failureCode: row.failure_code,
      refundStatus: row.refund_status, refundReason: row.refund_reason,
      refundRequestedAt: row.refund_requested_at,
    }));
    res.set('Cache-Control', 'no-store').json({
      available: true, payments, nextCursor: (data || []).length === 50 ? String(offset + 50) : null,
    });
  } catch (error) { fail(res, error); }
});
router.post('/payments/:orderId/refund', async (req, res) => {
  try {
    const orderId = req.params.orderId;
    const reason = typeof req.body?.reason === 'string' ? req.body.reason.trim().slice(0, 500) : '';
    if (!/^order_[a-zA-Z0-9]{8,60}$/.test(orderId) || reason.length < 5) {
      return res.status(400).json({ error: { message: 'Enter a valid order and refund reason.' } });
    }
    if (!process.env.RAZORPAY_KEY_ID || !process.env.RAZORPAY_KEY_SECRET) {
      return res.status(503).json({ error: { message: 'Razorpay is not configured.' } });
    }
    const { data: order, error } = await supabaseAdmin.from('employer_orders').select('*').eq('id', orderId).maybeSingle();
    if (error) throw Object.assign(new Error('Payment record is unavailable.'), { status: 503 });
    if (!order || order.status !== 'paid' || !order.payment_id ||
        (order.refund_status && order.refund_status !== 'failed')) {
      return res.status(409).json({ error: { message: 'This order is not eligible for a new refund request.' } });
    }
    const payment = await razorpayRequest(`/payments/${encodeURIComponent(order.payment_id)}`);
    if (payment.status !== 'captured' || payment.order_id !== order.id ||
        payment.amount !== order.amount_paise || payment.amount_refunded > 0) {
      return res.status(409).json({ error: { message: 'Razorpay payment status does not allow a full refund.' } });
    }
    let claim = supabaseAdmin.from('employer_orders').update({
      refund_status: 'requested', refund_reason: reason,
      refund_requested_at: new Date().toISOString(),
    }).eq('id', orderId).eq('status', 'paid');
    claim = order.refund_status == null ? claim.is('refund_status', null)
      : claim.eq('refund_status', order.refund_status);
    const { data: claimed, error: claimError } = await claim.select('id').maybeSingle();
    if (claimError) throw Object.assign(new Error('Could not reserve this refund.'), { status: 503 });
    if (!claimed) return res.status(409).json({ error: { message: 'A refund is already being handled.' } });
    const refund = await razorpayRequest(`/payments/${encodeURIComponent(order.payment_id)}/refund`, {
      method: 'POST',
      headers: { 'X-Refund-Idempotency': `career360_${orderId}` },
      body: JSON.stringify({ amount: order.amount_paise, speed: 'normal' }),
    });
    await supabaseAdmin.from('employer_orders').update({
      refund_id: refund.id, refund_status: refund.status || 'requested',
    }).eq('id', orderId);
    if (refund.status === 'processed') {
      const refreshed = await razorpayRequest(`/payments/${encodeURIComponent(order.payment_id)}`);
      await revokeFullyRefundedOrder(refreshed);
    }
    res.json({ status: refund.status || 'requested', refundId: refund.id || null });
  } catch (error) { fail(res, error); }
});
router.post('/payments/:orderId/reconcile', async (req, res) => {
  try {
    const { data: order, error } = await supabaseAdmin.from('employer_orders')
      .select('id,payment_id,amount_paise,refund_id,refund_status').eq('id', req.params.orderId).maybeSingle();
    if (error || !order?.payment_id || !order.refund_status) {
      return res.status(404).json({ error: { message: 'Refund record not found.' } });
    }
    const refund = order.refund_id
      ? await razorpayRequest(`/refunds/${encodeURIComponent(order.refund_id)}`)
      : await razorpayRequest(`/payments/${encodeURIComponent(order.payment_id)}/refund`, {
        method: 'POST', headers: { 'X-Refund-Idempotency': `career360_${order.id}` },
        body: JSON.stringify({ amount: order.amount_paise, speed: 'normal' }),
      });
    if (refund.payment_id !== order.payment_id) {
      return res.status(409).json({ error: { message: 'Refund does not match this payment.' } });
    }
    await supabaseAdmin.from('employer_orders').update({
      refund_id: refund.id, refund_status: refund.status,
    }).eq('id', order.id);
    if (refund.status === 'processed') {
      const payment = await razorpayRequest(`/payments/${encodeURIComponent(order.payment_id)}`);
      await revokeFullyRefundedOrder(payment);
    }
    res.json({ status: refund.status });
  } catch (error) { fail(res, error); }
});
const reportReasons = new Set(['fraud', 'misleading', 'duplicate', 'inappropriate', 'other']);
const reportStatuses = new Set(['pending', 'dismissed', 'job_closed']);
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function reportRecord(row) {
  const job = row.jobs || {};
  return {
    id: row.id, jobId: row.job_id, jobTitle: job.title || 'Job listing',
    companyName: job.company_name || '', jobStatus: job.status || '',
    reason: row.reason, details: row.details || '', status: row.status,
    createdAt: row.created_at, resolvedAt: row.resolved_at || null,
    resolutionNotes: row.resolution_notes || '',
  };
}

router.get('/reports', async (req, res) => {
  try {
    const status = req.query.status === 'all' ? 'all' :
      reportStatuses.has(req.query.status) ? req.query.status : 'pending';
    const reason = reportReasons.has(req.query.reason) ? req.query.reason : 'all';
    const search = typeof req.query.search === 'string'
      ? req.query.search.trim().slice(0, 80).replace(/[(),.%_*\\]/g, ' ').trim() : '';
    const offset = Number(req.query.cursor ?? 0);
    if (!Number.isSafeInteger(offset) || offset < 0 || offset > 100000) {
      return res.status(400).json({ error: { message: 'Invalid page cursor.' } });
    }
    let query = supabaseAdmin.from('job_reports').select(
      'id,job_id,reason,details,status,created_at,resolved_at,resolution_notes,jobs!inner(title,company_name,status)',
      { count: 'exact' },
    ).order('created_at', { ascending: false }).order('id', { ascending: false });
    if (status !== 'all') query = query.eq('status', status);
    if (reason !== 'all') query = query.eq('reason', reason);
    if (search) query = query.or(`title.ilike.%${search}%,company_name.ilike.%${search}%`,
      { referencedTable: 'jobs' });
    const [page, pending, dismissed, closed] = await Promise.all([
      query.range(offset, offset + 29),
      countRows('job_reports', (q) => q.eq('status', 'pending')),
      countRows('job_reports', (q) => q.eq('status', 'dismissed')),
      countRows('job_reports', (q) => q.eq('status', 'job_closed')),
    ]);
    if (page.error) throw Object.assign(new Error('Reports are temporarily unavailable.'), { status: 503 });
    const rows = page.data || [];
    res.set('Cache-Control', 'no-store').json({
      summary: { pending, dismissed, jobClosed: closed },
      reports: rows.map(reportRecord),
      total: page.count ?? rows.length,
      nextCursor: offset + rows.length < (page.count ?? offset + rows.length)
        ? String(offset + rows.length) : null,
    });
  } catch (error) { fail(res, error); }
});

router.get('/reports/:id', async (req, res) => {
  try {
    if (!uuid.test(req.params.id)) return res.status(400).json({ error: { message: 'Invalid report ID.' } });
    const { data: report, error } = await supabaseAdmin.from('job_reports')
      .select('id,job_id,reason,details,status,created_at,resolved_at,resolution_notes,resolved_by')
      .eq('id', req.params.id).maybeSingle();
    if (error) throw Object.assign(new Error('Report is temporarily unavailable.'), { status: 503 });
    if (!report) return res.status(404).json({ error: { message: 'Report not found.' } });
    const [jobResult, relatedResult] = await Promise.all([
      supabaseAdmin.from('jobs').select('id,employer_id,title,company_name,description,category,district,salary_text,status,created_at,expires_at')
        .eq('id', report.job_id).maybeSingle(),
      supabaseAdmin.from('job_reports').select('id,reason,details,status,created_at')
        .eq('job_id', report.job_id).order('created_at', { ascending: false }).limit(100),
    ]);
    if (jobResult.error || relatedResult.error) throw Object.assign(new Error('Report details are temporarily unavailable.'), { status: 503 });
    const job = jobResult.data;
    const { data: employer, error: employerError } = job?.employer_id
      ? await supabaseAdmin.from('employers').select('company_name').eq('id', job.employer_id).maybeSingle()
      : { data: null, error: null };
    if (employerError) throw Object.assign(new Error('Company details are temporarily unavailable.'), { status: 503 });
    res.set('Cache-Control', 'no-store').json({
      report: { ...reportRecord({ ...report, jobs: job }), resolvedBy: report.resolved_by || null },
      job: job ? { id: job.id, title: job.title, companyName: employer?.company_name || job.company_name || '',
        description: job.description || '', category: job.category || '', district: job.district || '',
        salaryText: job.salary_text || '', status: job.status, createdAt: job.created_at,
        expiresAt: job.expires_at } : null,
      relatedReports: (relatedResult.data || []).map((row) => ({
        id: row.id, reason: row.reason, details: row.details || '',
        status: row.status, createdAt: row.created_at,
      })),
    });
  } catch (error) { fail(res, error); }
});

router.post('/reports/:id/resolve', async (req, res) => {
  try {
    if (!uuid.test(req.params.id)) return res.status(400).json({ error: { message: 'Invalid report ID.' } });
    const decision = req.body?.decision;
    const notes = typeof req.body?.notes === 'string' ? req.body.notes.trim() : '';
    if (!['dismissed', 'job_closed'].includes(decision) || notes.length > 1000 ||
        (decision === 'job_closed' && notes.length < 5)) {
      return res.status(400).json({ error: { message: 'Choose a decision and add a reason of at least five characters to close a job.' } });
    }
    const { data, error } = await supabaseAdmin.rpc('resolve_job_report', {
      p_report_id: req.params.id, p_actor_uid: req.user.uid,
      p_decision: decision, p_notes: notes,
    });
    if (error) {
      if (/already been reviewed|only a published|not found/i.test(error.message)) {
        return res.status(409).json({ error: { message: error.message } });
      }
      throw Object.assign(new Error('Could not resolve this report.'), { status: 503 });
    }
    if (decision === 'job_closed' && data?.employerUid) {
      try {
        const notice = await supabaseAdmin.from('notifications').insert({
          user_id: data.employerUid, title: 'Job listing closed',
          message: `Career360 closed your listing "${data.jobTitle}" after review. ${notes}`,
          type: 'job_moderation',
        });
        if (notice.error) console.warn('[Report notification]', notice.error.message);
        sendNotificationToUser({ userId: data.employerUid,
          title: 'Job listing closed',
          body: `Your listing "${data.jobTitle}" was closed after review. Open the employer portal for details.`,
          type: 'job_moderation', metadata: { jobId: data.jobId },
        }).catch((pushError) => console.warn('[Report push]', pushError.message));
      } catch (notificationError) {
        console.warn('[Report notification]', notificationError);
      }
    }
    res.set('Cache-Control', 'no-store').json({ status: data.status, affectedReports: data.affectedReports });
  } catch (error) { fail(res, error); }
});

export default router;
