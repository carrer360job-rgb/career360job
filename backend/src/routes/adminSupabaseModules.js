import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { initialPlanDrafts, publicPlan, validatePlanDraft } from '../services/planCatalog.js';

const router = express.Router();
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const contentKinds = new Set(['category', 'announcement']);

function fail(res, error) {
  console.error('[Admin Supabase API]', error);
  const status = error.status || 503;
  return res.status(status).json({ error: { message: error.status ? error.message : 'This admin section is temporarily unavailable.' } });
}

function unavailable(message) {
  return Object.assign(new Error(message), { status: 503 });
}

function pageOffset(value) {
  const offset = value === undefined ? 0 : Number(value);
  if (!Number.isSafeInteger(offset) || offset < 0 || offset > 100000) {
    throw Object.assign(new Error('Invalid page cursor.'), { status: 400 });
  }
  return offset;
}

async function audit(actorUid, action, targetType, targetId, notes = null) {
  const { error } = await supabaseAdmin.from('admin_audit').insert({
    actor_uid: actorUid, action, target_type: targetType, target_id: targetId,
    notes,
  });
  if (error) console.error('[Admin audit]', error);
}

function moneyRange(row) {
  const format = (value) => `₹${Number(value).toLocaleString('en-IN')}`;
  if (row.min_salary != null && row.max_salary != null) return `${format(row.min_salary)}–${format(row.max_salary)} / ${row.salary_type || 'month'}`;
  if (row.min_salary != null) return `From ${format(row.min_salary)} / ${row.salary_type || 'month'}`;
  if (row.max_salary != null) return `Up to ${format(row.max_salary)} / ${row.salary_type || 'month'}`;
  return 'Not specified';
}

router.get('/jobs', async (req, res) => {
  try {
    const offset = pageOffset(req.query.cursor);
    const status = ['active', 'closed'].includes(req.query.status) ? req.query.status : 'all';
    const search = typeof req.query.search === 'string' ? req.query.search.trim().toLowerCase() : '';
    let query = supabaseAdmin.from('jobs').select('id,employer_id,title,category,district,job_type,min_salary,max_salary,salary_type,vacancies,contact_phone,contact_whatsapp,contact_email,status,created_at,expires_at')
      .order('created_at', { ascending: false });
    if (status !== 'all') query = query.eq('status', status === 'active' ? 'PUBLISHED' : 'CLOSED');
    const { data: rows, error } = await query.range(offset, offset + 49);
    if (error) throw unavailable('Job listings are temporarily unavailable.');
    const employerIds = [...new Set((rows || []).map((row) => row.employer_id).filter(Boolean))];
    const { data: employers, error: employerError } = employerIds.length
      ? await supabaseAdmin.from('employers').select('id,company_name,contact_name,is_verified').in('id', employerIds)
      : { data: [], error: null };
    if (employerError) throw unavailable('Company details are temporarily unavailable.');
    const companyById = new Map((employers || []).map((row) => [row.id, row]));
    let jobs = (rows || []).map((row) => {
      const employer = companyById.get(row.employer_id) || {};
      return { id: row.id, title: row.title, companyName: employer.company_name || '',
        category: row.category || '', locationCity: row.district || '', workMode: row.job_type || '',
        salaryText: moneyRange(row), vacanciesCount: row.vacancies || 1,
        phone: row.contact_phone || '', whatsappNumber: row.contact_whatsapp || '',
        email: row.contact_email || '', contactName: employer.contact_name || '',
        status: row.status === 'PUBLISHED' ? 'active' : 'closed', isVerified: employer.is_verified === true,
        postedAt: row.created_at || null, expiresAt: row.expires_at || null };
    });
    if (search) jobs = jobs.filter((job) => [job.title, job.companyName, job.locationCity, job.contactName]
      .some((value) => value.toLowerCase().includes(search)));
    res.set('Cache-Control', 'no-store').json({ jobs, nextCursor: (rows || []).length === 50 ? String(offset + 50) : null });
  } catch (error) { fail(res, error); }
});

router.post('/jobs/:id/close', async (req, res) => {
  try {
    if (!uuid.test(req.params.id)) return res.status(400).json({ error: { message: 'Invalid job ID.' } });
    const { data, error } = await supabaseAdmin.from('jobs').update({ status: 'CLOSED', updated_at: new Date().toISOString() })
      .eq('id', req.params.id).eq('status', 'PUBLISHED').select('id').maybeSingle();
    if (error) throw unavailable('Could not close this job.');
    if (!data) return res.status(404).json({ error: { message: 'Active job not found.' } });
    await audit(req.user.uid, 'job_force_closed', 'job', req.params.id);
    res.json({ status: 'closed' });
  } catch (error) { fail(res, error); }
});

router.get('/job-seekers', async (req, res) => {
  try {
    const page = pageOffset(req.query.pageToken) + 1;
    const search = String(req.query.search || '').trim().toLowerCase();
    const { data, error } = await supabaseAdmin.auth.admin.listUsers({ page, perPage: 100 });
    if (error) throw unavailable('Job seeker accounts are temporarily unavailable.');
    const users = data?.users || [];
    const ids = users.map((user) => user.id);
    const [profileResult, candidateResult] = ids.length ? await Promise.all([
      supabaseAdmin.from('profiles').select('id,role,status').in('id', ids),
      supabaseAdmin.from('candidate_profiles').select('user_id,full_name').in('user_id', ids),
    ]) : [{ data: [], error: null }, { data: [], error: null }];
    if (profileResult.error || candidateResult.error) throw unavailable('Job seeker profiles are temporarily unavailable.');
    const profiles = new Map(profileResult.data.map((row) => [row.id, row]));
    const names = new Map(candidateResult.data.map((row) => [row.user_id, row.full_name]));
    const records = users.flatMap((user) => {
      const profile = profiles.get(user.id);
      if (profile?.role !== 'CANDIDATE') return [];
      return [{ uid: user.id, email: user.email || '', displayName: names.get(user.id) || '',
        disabled: ['SUSPENDED', 'BLOCKED'].includes(profile?.status) || Boolean(user.banned_until && new Date(user.banned_until) > new Date()),
        emailVerified: Boolean(user.email_confirmed_at), createdAt: user.created_at || null,
        lastSignInAt: user.last_sign_in_at || null }];
    });
    const filtered = search ? records.filter((user) => [user.email, user.displayName, user.uid]
      .some((value) => value.toLowerCase().includes(search))) : records;
    res.set('Cache-Control', 'no-store').json({ jobSeekers: filtered, nextPageToken: users.length === 100 ? String(page) : null });
  } catch (error) { fail(res, error); }
});

router.get('/job-seekers/:uid', async (req, res) => {
  try {
    const uid = req.params.uid;
    if (!uuid.test(uid)) return res.status(400).json({ error: { message: 'Invalid job seeker ID.' } });
    const [authResult, profileResult, candidateResult] = await Promise.all([
      supabaseAdmin.auth.admin.getUserById(uid),
      supabaseAdmin.from('profiles').select('id,role,status,email,phone').eq('id', uid).maybeSingle(),
      supabaseAdmin.from('candidate_profiles').select(
        'full_name,district,personal_details,education,preferred_job_titles,experience,profile_photo_url,onboarding_step,onboarding_completed_at,created_at,updated_at'
      ).eq('user_id', uid).maybeSingle(),
    ]);
    if (authResult.error || profileResult.error || candidateResult.error) {
      throw unavailable('Job seeker details are temporarily unavailable.');
    }
    const user = authResult.data?.user;
    const profile = profileResult.data;
    if (!user || !profile || profile.role !== 'CANDIDATE') {
      return res.status(404).json({ error: { message: 'Job seeker account not found.' } });
    }
    const candidate = candidateResult.data || {};
    res.set('Cache-Control', 'no-store').json({ jobSeeker: {
      uid,
      email: profile.email || user.email || '',
      phone: profile.phone || '',
      emailVerified: Boolean(user.email_confirmed_at),
      createdAt: user.created_at || null,
      lastSignInAt: user.last_sign_in_at || null,
      disabled: ['SUSPENDED', 'BLOCKED'].includes(profile.status) || Boolean(user.banned_until && new Date(user.banned_until) > new Date()),
      profile: {
        fullName: candidate.full_name || '',
        district: candidate.district || '',
        personalDetails: candidate.personal_details || {},
        education: candidate.education || {},
        preferredJobTitles: candidate.preferred_job_titles || [],
        experience: candidate.experience || {},
        profilePhotoUrl: candidate.profile_photo_url || null,
        onboardingStep: candidate.onboarding_step ?? 0,
        onboardingCompletedAt: candidate.onboarding_completed_at || null,
        createdAt: candidate.created_at || null,
        updatedAt: candidate.updated_at || null,
      },
    } });
  } catch (error) { fail(res, error); }
});

router.post('/users/:uid/status', async (req, res) => {
  try {
    const uid = req.params.uid;
    const disabled = req.body?.disabled;
    const reason = typeof req.body?.reason === 'string' ? req.body.reason.trim().slice(0, 300) : '';
    if (!uuid.test(uid) || uid === req.user.uid) return res.status(400).json({ error: { message: 'Invalid account or your own admin account.' } });
    if (typeof disabled !== 'boolean' || (disabled && reason.length < 5)) return res.status(400).json({ error: { message: 'Provide a reason when suspending an account.' } });
    const { data: profile, error: lookupError } = await supabaseAdmin.from('profiles').select('id,role').eq('id', uid).maybeSingle();
    if (lookupError) throw unavailable('Account status is temporarily unavailable.');
    if (!profile) return res.status(404).json({ error: { message: 'Account not found.' } });
    if (profile.role === 'ADMIN') return res.status(403).json({ error: { message: 'Admin accounts cannot be changed here.' } });
    if (disabled) {
      const { error: banError } = await supabaseAdmin.auth.admin.updateUserById(uid, { ban_duration: '876000h' });
      if (banError) throw unavailable('Could not suspend this account.');
    }
    const { error: profileError } = await supabaseAdmin.from('profiles').update({
      status: disabled ? 'SUSPENDED' : 'ACTIVE', updated_at: new Date().toISOString(),
    }).eq('id', uid);
    if (profileError) throw unavailable('Could not update this account.');
    if (disabled && profile.role === 'EMPLOYER') {
      const { data: employer } = await supabaseAdmin.from('employers').select('id').eq('user_id', uid).maybeSingle();
      if (employer?.id) await supabaseAdmin.from('jobs').update({ status: 'CLOSED', updated_at: new Date().toISOString() })
        .eq('employer_id', employer.id).eq('status', 'PUBLISHED');
    }
    if (!disabled) {
      const { error: unbanError } = await supabaseAdmin.auth.admin.updateUserById(uid, { ban_duration: 'none' });
      if (unbanError) throw unavailable('Could not restore sign-in for this account.');
    }
    await audit(req.user.uid, disabled ? 'user_suspended' : 'user_activated', 'user', uid, reason || null);
    res.json({ uid, disabled });
  } catch (error) { fail(res, error); }
});

function planDraft(row) {
  if (row.draft) return row.draft;
  return { name: row.name, tier: row.tier, badge: row.badge || '', pricePaise: Number(row.price_paise),
    taxMode: row.tax_mode || 'inclusive', taxRateBps: row.tax_rate_bps ?? 1800,
    jobCredits: row.job_credits, listingDays: row.listing_days,
    creditValidityDays: row.credit_validity_days || row.listing_days,
    profileUnlockLimit: row.profile_unlock_limit ?? 25, reach: row.reach || 'district',
    sortOrder: row.sort_order || 0, features: row.features || [] };
}

router.get('/plans', async (_req, res) => {
  try {
    const { data, error } = await supabaseAdmin.from('employer_plans').select('*').gt('price_paise', 0).order('sort_order', { ascending: true });
    if (error) throw unavailable('Hiring plans are temporarily unavailable.');
    const plans = (data || []).map((row) => {
      const draft = planDraft(row);
      return { id: row.id, version: row.version || 1, draft,
        published: row.is_active ? publicPlan(row.id, row.version || 1, { ...planDraft({ ...row, draft: null }), active: true }) : null };
    });
    res.set('Cache-Control', 'no-store').json({ plans });
  } catch (error) { fail(res, error); }
});

router.post('/plans/seed', async (_req, res) => {
  try {
    const rows = initialPlanDrafts.map((plan) => ({ id: plan.id, name: plan.name, tier: plan.tier,
      price_paise: plan.pricePaise, job_credits: plan.jobCredits, listing_days: plan.listingDays,
      reach: plan.reach, features: plan.features, is_active: false, version: 0, draft: plan }));
    const { error } = await supabaseAdmin.from('employer_plans').upsert(rows, { onConflict: 'id', ignoreDuplicates: true });
    if (error) throw unavailable('Could not create plan drafts.');
    res.status(201).json({ status: 'drafts_created' });
  } catch (error) { fail(res, error); }
});

router.put('/plans/:id/draft', async (req, res) => {
  try {
    const id = req.params.id;
    if (!/^[a-z][a-z0-9_]{2,39}$/.test(id)) return res.status(400).json({ error: { message: 'Invalid plan ID.' } });
    const draft = validatePlanDraft(req.body);
    const { data: existing, error: lookupError } = await supabaseAdmin.from('employer_plans').select('id').eq('id', id).maybeSingle();
    if (lookupError) throw unavailable('Could not load this plan.');
    const values = { draft, updated_at: new Date().toISOString() };
    const result = existing
      ? await supabaseAdmin.from('employer_plans').update(values).eq('id', id)
      : await supabaseAdmin.from('employer_plans').insert({ id, name: draft.name, tier: draft.tier,
        price_paise: draft.pricePaise, job_credits: draft.jobCredits, listing_days: draft.listingDays,
        reach: draft.reach, features: draft.features, is_active: false, version: 0, ...values });
    if (result.error) throw unavailable('Could not save this plan draft.');
    res.json({ id, draft });
  } catch (error) { fail(res, error); }
});

router.post('/plans/:id/publish', async (req, res) => {
  try {
    const { data: row, error: lookupError } = await supabaseAdmin.from('employer_plans').select('*').eq('id', req.params.id).maybeSingle();
    if (lookupError) throw unavailable('Could not load this plan.');
    if (!row?.draft) return res.status(404).json({ error: { message: 'Save a draft first.' } });
    const draft = validatePlanDraft(row.draft);
    const version = (row.version || 0) + 1;
    const { data: updated, error } = await supabaseAdmin.from('employer_plans').update({
      name: draft.name, tier: draft.tier, badge: draft.badge, price_paise: draft.pricePaise,
      tax_mode: draft.taxMode, tax_rate_bps: draft.taxRateBps, job_credits: draft.jobCredits,
      listing_days: draft.listingDays, credit_validity_days: draft.creditValidityDays,
      profile_unlock_limit: draft.profileUnlockLimit, reach: draft.reach, sort_order: draft.sortOrder,
      features: draft.features, is_active: true, version, updated_at: new Date().toISOString(),
    }).eq('id', row.id).eq('version', row.version).select('id').maybeSingle();
    if (error) throw unavailable('Could not publish this plan.');
    if (!updated) return res.status(409).json({ error: { message: 'This plan changed. Refresh and try again.' } });
    await audit(req.user.uid, 'plan_publish', 'plan', row.id, `Version ${version}`);
    res.json({ plan: publicPlan(row.id, version, { ...draft, active: true }) });
  } catch (error) { fail(res, error); }
});

router.post('/plans/:id/archive', async (req, res) => {
  try {
    const { data, error } = await supabaseAdmin.from('employer_plans').update({ is_active: false, updated_at: new Date().toISOString() })
      .eq('id', req.params.id).eq('is_active', true).select('id').maybeSingle();
    if (error) throw unavailable('Could not archive this plan.');
    if (!data) return res.status(404).json({ error: { message: 'Published plan not found.' } });
    await audit(req.user.uid, 'plan_archive', 'plan', req.params.id);
    res.json({ status: 'archived' });
  } catch (error) { fail(res, error); }
});

function contentPayload(body = {}) {
  const kind = body.kind;
  const title = typeof body.title === 'string' ? body.title.trim() : '';
  const content = typeof body.content === 'string' ? body.content.trim() : '';
  if (!contentKinds.has(kind) || title.length < 2 || title.length > 100 || content.length > 12000) {
    throw Object.assign(new Error('Enter a valid content type, title and content.'), { status: 400 });
  }
  return { kind, title, content, active: body.active !== false,
    sort_order: Number.isInteger(body.sortOrder) ? Math.max(0, Math.min(1000, body.sortOrder)) : 0 };
}

function contentView(row) {
  return { id: row.id, kind: row.kind, title: row.title, content: row.content,
    active: row.active, sortOrder: row.sort_order, createdAt: row.created_at, updatedAt: row.updated_at };
}

router.get('/content', async (_req, res) => {
  try {
    const { data, error } = await supabaseAdmin.from('platform_content').select('*').order('sort_order', { ascending: true }).limit(500);
    if (error) throw unavailable('Platform content is temporarily unavailable.');
    res.set('Cache-Control', 'no-store').json({ items: (data || []).map(contentView) });
  } catch (error) { fail(res, error); }
});

router.post('/content', async (req, res) => {
  try {
    const payload = contentPayload(req.body);
    const { data, error } = await supabaseAdmin.from('platform_content').insert({ ...payload,
      created_by: req.user.uid, updated_by: req.user.uid }).select('*').single();
    if (error) throw unavailable('Could not create content.');
    await audit(req.user.uid, 'content_created', 'content', data.id);
    res.status(201).json(contentView(data));
  } catch (error) { fail(res, error); }
});

router.put('/content/:id', async (req, res) => {
  try {
    if (!uuid.test(req.params.id)) return res.status(400).json({ error: { message: 'Invalid content ID.' } });
    const payload = contentPayload(req.body);
    const { data, error } = await supabaseAdmin.from('platform_content').update({ ...payload,
      updated_by: req.user.uid, updated_at: new Date().toISOString() })
      .eq('id', req.params.id).select('*').maybeSingle();
    if (error) throw unavailable('Could not update content.');
    if (!data) return res.status(404).json({ error: { message: 'Content item not found.' } });
    await audit(req.user.uid, 'content_updated', 'content', data.id);
    res.json(contentView(data));
  } catch (error) { fail(res, error); }
});

router.delete('/content/:id', async (req, res) => {
  try {
    if (!uuid.test(req.params.id)) return res.status(400).json({ error: { message: 'Invalid content ID.' } });
    const { data, error } = await supabaseAdmin.from('platform_content').delete().eq('id', req.params.id).select('id').maybeSingle();
    if (error) throw unavailable('Could not delete content.');
    if (!data) return res.status(404).json({ error: { message: 'Content item not found.' } });
    await audit(req.user.uid, 'content_deleted', 'content', data.id);
    res.json({ status: 'deleted' });
  } catch (error) { fail(res, error); }
});

export default router;
