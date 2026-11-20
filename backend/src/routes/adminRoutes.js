import express from 'express';
import { verifyAdminToken } from '../middlewares/authMiddleware.js';
import { requireAdmin } from '../middlewares/adminMiddleware.js';
import { supabaseAdmin } from '../config/supabase.js';
import adminSupabaseModules from './adminSupabaseModules.js';

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
    } });
  } catch (error) {
    fail(res, error);
  }
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

// Billing and job reports still depend on records in the legacy store. An
// unavailable response must not pretend there are zero payments or reports.
router.get('/payments', (_req, res) => {
  return res.set('Cache-Control', 'no-store').json({ available: false, payments: [], nextCursor: null });
});
router.get('/reports', (_req, res) => {
  return res.set('Cache-Control', 'no-store').json({ available: false, summary: null, reports: [], nextCursor: null });
});
router.post(['/payments/:orderId/refund', '/payments/:orderId/reconcile', '/reports/:id/resolve'], (_req, res) => {
  return res.status(503).json({ error: { message: 'This admin action is temporarily unavailable.' } });
});

export default router;
