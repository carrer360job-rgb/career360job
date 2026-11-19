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
    // Supabase is the source of truth for employer profiles. Fetch in pages so
    // the admin directory does not depend on Firebase credentials in Vercel.
    const { data: rows, error } = await supabaseAdmin.from('employers')
      .select('user_id,company_name,contact_name,designation,email,phone,whatsapp_phone,industry,company_size,state,district,address,postal_code,posting_credits,active_plan,is_verified,created_at,reviewed_by,reviewed_at,rejection_reason')
      .order('created_at', { ascending: false }).range(offset, offset + 49);
    if (error) throw Object.assign(new Error('Employer directory is unavailable.'), { status: 503 });
    const userIds = (rows || []).map((row) => row.user_id).filter(Boolean);
    const { data: profiles, error: profilesError } = userIds.length
      ? await supabaseAdmin.from('profiles').select('id,status').in('id', userIds)
      : { data: [], error: null };
    if (profilesError) throw Object.assign(new Error('Employer account status is unavailable.'), { status: 503 });
    const profileStatus = new Map((profiles || []).map((profile) => [profile.id, profile.status]));
    let employers = (rows || []).map((row) => {
      const accountStatus = profileStatus.get(row.user_id);
      const status = accountStatus === 'SUSPENDED' || accountStatus === 'BLOCKED'
        ? 'rejected' : row.is_verified ? 'approved' : 'pending';
      return { uid: row.user_id, companyName: row.company_name || '', contactName: row.contact_name || '',
        designation: row.designation || '', email: row.email || '', phone: row.phone || '',
        whatsappPhone: row.whatsapp_phone || row.phone || '', industry: row.industry || '',
        companySize: row.company_size || '', state: row.state || '', district: row.district || '',
        address: row.address || '', postalCode: row.postal_code || '', registrationNumber: '',
        status, postingCredits: row.posting_credits || 0, activePlan: row.active_plan || '',
        rejectionReason: row.rejection_reason || null, reviewedBy: row.reviewed_by || null,
        reviewedAt: row.reviewed_at || null, createdAt: row.created_at || null };
    });
    if (statusFilter !== 'all') employers = employers.filter((employer) => employer.status === statusFilter);
    if (search) employers = employers.filter((employer) => [employer.companyName, employer.contactName,
      employer.email, employer.phone, employer.district].some((field) => field.toLowerCase().includes(search)));
    res.set('Cache-Control', 'no-store');
    res.json({ employers, nextCursor: (rows || []).length === 50 ? String(offset + 50) : null });
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
