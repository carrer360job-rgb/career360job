import express from 'express';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { firebaseApp } from '../config/firebase.js';
import { verifyAdminToken } from '../middlewares/authMiddleware.js';
import { requireAdmin } from '../middlewares/adminMiddleware.js';
import { catalogDb, publicPlan, seedPlanDrafts, validatePlanDraft } from '../services/planCatalog.js';

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

// 1. Platform Statistics Dashboard
router.get('/stats', async (req, res) => {
  try {
    const db = getFirestore(firebaseApp);
    const [employersSnap, candidatesSnap, jobsSnap, applicationsSnap] = await Promise.all([
      db.collection('employers').get(),
      db.collection('candidates').get(),
      db.collection('jobs').get(),
      db.collection('applications').get(),
    ]);

    let pendingEmployers = 0;
    let approvedEmployers = 0;
    let rejectedEmployers = 0;
    employersSnap.forEach((doc) => {
      const st = doc.data().status;
      if (st === 'pending') pendingEmployers++;
      else if (st === 'approved') approvedEmployers++;
      else if (st === 'rejected') rejectedEmployers++;
    });

    let activeJobs = 0;
    let closedJobs = 0;
    jobsSnap.forEach((doc) => {
      if (doc.data().status === 'active') activeJobs++;
      else closedJobs++;
    });

    res.set('Cache-Control', 'no-store');
    res.json({
      totalCandidates: candidatesSnap.size,
      totalEmployers: employersSnap.size,
      pendingEmployers,
      approvedEmployers,
      rejectedEmployers,
      totalJobs: jobsSnap.size,
      activeJobs,
      closedJobs,
      totalApplications: applicationsSnap.size,
    });
  } catch (error) {
    fail(res, error);
  }
});

// 2. Employers List with Filtering
router.get('/employers', async (req, res) => {
  try {
    const db = getFirestore(firebaseApp);
    const statusFilter = req.query.status || 'all';
    const search = (req.query.search || '').trim().toLowerCase();

    let query = db.collection('employers');
    if (['pending', 'approved', 'rejected'].includes(statusFilter)) {
      query = query.where('status', '==', statusFilter);
    }

    const snap = await query.get();
    let employers = snap.docs.map((doc) => {
      const data = doc.data();
      return {
        uid: doc.id,
        companyName: data.companyName || '',
        contactName: data.contactName || '',
        designation: data.designation || '',
        email: data.email || '',
        phone: data.phone || '',
        whatsappPhone: data.whatsappPhone || data.phone || '',
        industry: data.industry || '',
        companySize: data.companySize || '',
        state: data.state || '',
        district: data.district || '',
        address: data.address || '',
        postalCode: data.postalCode || '',
        registrationNumber: data.registrationNumber || '',
        status: data.status || 'pending',
        postingCredits: data.postingCredits || 0,
        activePlan: data.activePlan || 'free_starter',
        rejectionReason: data.rejectionReason || null,
        reviewedBy: data.reviewedBy || null,
        createdAt: data.createdAt?.toDate?.()?.toISOString() || null,
        reviewedAt: data.reviewedAt?.toDate?.()?.toISOString() || null,
      };
    });

    if (search) {
      employers = employers.filter((e) =>
        e.companyName.toLowerCase().includes(search) ||
        e.contactName.toLowerCase().includes(search) ||
        e.email.toLowerCase().includes(search) ||
        e.phone.includes(search) ||
        e.district.toLowerCase().includes(search)
      );
    }

    // Sort pending first, then by createdAt desc
    employers.sort((a, b) => {
      if (a.status === 'pending' && b.status !== 'pending') return -1;
      if (a.status !== 'pending' && b.status === 'pending') return 1;
      return (b.createdAt || '').localeCompare(a.createdAt || '');
    });

    res.set('Cache-Control', 'no-store');
    res.json({ employers });
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

    const db = getFirestore(firebaseApp);
    const employerRef = db.collection('employers').doc(uid);
    const userRef = db.collection('users').doc(uid);

    const result = await db.runTransaction(async (tx) => {
      const employerDoc = await tx.get(employerRef);
      if (!employerDoc.exists) {
        throw Object.assign(new Error('Employer account not found.'), { status: 404 });
      }
      const data = employerDoc.data();
      const now = Date.now();
      const updates = {
        status: decision,
        reviewedBy: req.user.uid,
        reviewedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (decision === 'approved') {
        const existingExpiry = data.creditsExpireAt?.toMillis?.() ?? 0;
        const activeCredits = existingExpiry > now ? (data.postingCredits ?? 0) : 0;
        const newCredits = Math.max(activeCredits, 1);
        const nextExpiry = Math.max(existingExpiry, now + 7 * 86400000);

        updates.postingCredits = newCredits;
        updates.listingDays = data.listingDays || 7;
        updates.creditsExpireAt = Timestamp.fromMillis(nextExpiry);
        updates.activePlan = data.activePlan || 'free_starter';
        updates.rejectionReason = FieldValue.delete();
      } else {
        updates.rejectionReason = notes ? String(notes).trim().slice(0, 500) : 'Company verification could not be completed.';
      }

      tx.update(employerRef, updates);

      // In-app notification
      const notifRef = userRef.collection('notifications').doc();
      tx.create(notifRef, {
        title: decision === 'approved' ? 'Company Verified ✔️' : 'Company Verification Update',
        body: decision === 'approved'
          ? 'Your company profile has been approved! 1 free job posting credit is ready in your account.'
          : `Verification note: ${updates.rejectionReason}`,
        type: 'employer_review',
        decision,
        createdAt: FieldValue.serverTimestamp(),
        readAt: null,
      });

      // Audit log
      tx.create(db.collection('admin_audit').doc(), {
        action: `employer_${decision}`,
        actorUid: req.user.uid,
        employerUid: uid,
        notes: notes || null,
        createdAt: FieldValue.serverTimestamp(),
      });

      return { uid, status: decision };
    });

    res.json(result);
  } catch (error) {
    fail(res, error);
  }
});

// 4. Jobs Moderation List
router.get('/jobs', async (req, res) => {
  try {
    const db = getFirestore(firebaseApp);
    const status = req.query.status || 'all';
    const search = (req.query.search || '').trim().toLowerCase();

    let query = db.collection('jobs');
    if (['active', 'closed'].includes(status)) {
      query = query.where('status', '==', status);
    }

    const snap = await query.get();
    let jobs = snap.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        title: data.title || '',
        companyName: data.companyName || '',
        category: data.category || '',
        locationCity: data.locationCity || '',
        workMode: data.workMode || 'On-site',
        salaryText: data.salaryText || '',
        vacanciesCount: data.vacanciesCount || 1,
        phone: data.phone || '',
        whatsappNumber: data.whatsappNumber || '',
        email: data.email || '',
        contactName: data.contactName || '',
        status: data.status || 'active',
        isVerified: data.isVerified === true,
        postedAt: data.postedAt?.toDate?.()?.toISOString() || null,
        expiresAt: data.expiresAt?.toDate?.()?.toISOString() || null,
      };
    });

    if (search) {
      jobs = jobs.filter((j) =>
        j.title.toLowerCase().includes(search) ||
        j.companyName.toLowerCase().includes(search) ||
        j.locationCity.toLowerCase().includes(search) ||
        j.contactName.toLowerCase().includes(search)
      );
    }

    jobs.sort((a, b) => (b.postedAt || '').localeCompare(a.postedAt || ''));
    res.set('Cache-Control', 'no-store');
    res.json({ jobs });
  } catch (error) {
    fail(res, error);
  }
});

// 5. Force Close Job (Takedown Spam)
router.post('/jobs/:id/close', async (req, res) => {
  try {
    const db = getFirestore(firebaseApp);
    const jobRef = db.collection('jobs').doc(req.params.id);
    const job = await jobRef.get();
    if (!job.exists) return res.status(404).json({ error: { message: 'Job not found.' } });
    await jobRef.update({
      status: 'closed',
      closedBy: 'admin',
      closedAt: FieldValue.serverTimestamp(),
    });
    await db.collection('admin_audit').doc().create({
      action: 'job_force_closed',
      actorUid: req.user.uid,
      jobId: req.params.id,
      createdAt: FieldValue.serverTimestamp(),
    });
    res.json({ status: 'closed' });
  } catch (error) {
    fail(res, error);
  }
});

// Plans Catalog Management
router.get('/plans', async (req, res) => {
  try {
    const snapshot = await catalogDb().collection('employer_plans').get();
    res.set('Cache-Control', 'no-store');
    res.json({ plans: snapshot.docs.map((doc) => ({
      id: doc.id, version: doc.data().version || 0,
      draft: doc.data().draft || null,
      published: doc.data().published?.active ? publicPlan(doc.id, doc.data().version, doc.data().published) : null,
    })).sort((a, b) => (a.draft?.sortOrder ?? 999) - (b.draft?.sortOrder ?? 999)) });
  } catch (error) { fail(res, error); }
});

router.post('/plans/seed', async (req, res) => {
  try {
    await seedPlanDrafts(req.user.uid);
    res.status(201).json({ status: 'drafts_created' });
  } catch (error) { fail(res, error); }
});

router.put('/plans/:id/draft', async (req, res) => {
  try {
    const id = req.params.id;
    if (!/^[a-z][a-z0-9_]{2,39}$/.test(id)) return res.status(400).json({ error: { message: 'Invalid plan ID.' } });
    const draft = validatePlanDraft(req.body);
    const database = catalogDb();
    const ref = database.collection('employer_plans').doc(id);
    await database.runTransaction(async (tx) => {
      const existing = await tx.get(ref);
      const values = { draft, updatedAt: FieldValue.serverTimestamp(), updatedBy: req.user.uid };
      if (existing.exists) tx.update(ref, values);
      else tx.create(ref, { ...values, version: 0, createdAt: FieldValue.serverTimestamp() });
    });
    res.json({ id, draft });
  } catch (error) { fail(res, error); }
});

router.post('/plans/:id/publish', async (req, res) => {
  try {
    const database = catalogDb();
    const ref = database.collection('employer_plans').doc(req.params.id);
    const result = await database.runTransaction(async (tx) => {
      const doc = await tx.get(ref);
      if (!doc.exists || !doc.data().draft) throw Object.assign(new Error('Save a draft first.'), { status: 404 });
      const draft = validatePlanDraft(doc.data().draft);
      const version = (doc.data().version || 0) + 1;
      const published = { ...draft, active: true };
      tx.create(database.collection('employer_plan_versions').doc(`${ref.id}_v${version}`), {
        planId: ref.id, version, ...published, publishedAt: FieldValue.serverTimestamp(), publishedBy: req.user.uid,
      });
      tx.update(ref, { published, version, publishedAt: FieldValue.serverTimestamp(), publishedBy: req.user.uid });
      tx.create(database.collection('admin_audit').doc(), {
        action: 'plan_publish', actorUid: req.user.uid, planId: ref.id, version,
        createdAt: FieldValue.serverTimestamp(),
      });
      return publicPlan(ref.id, version, published);
    });
    res.json({ plan: result });
  } catch (error) { fail(res, error); }
});

router.post('/plans/:id/archive', async (req, res) => {
  try {
    const database = catalogDb();
    const ref = database.collection('employer_plans').doc(req.params.id);
    await database.runTransaction(async (tx) => {
      const doc = await tx.get(ref);
      if (!doc.exists || !doc.data().published?.active) throw Object.assign(new Error('Published plan not found.'), { status: 404 });
      tx.update(ref, { 'published.active': false, archivedAt: FieldValue.serverTimestamp(), archivedBy: req.user.uid });
      tx.create(database.collection('admin_audit').doc(), {
        action: 'plan_archive', actorUid: req.user.uid, planId: ref.id,
        version: doc.data().version, createdAt: FieldValue.serverTimestamp(),
      });
    });
    res.json({ status: 'archived' });
  } catch (error) { fail(res, error); }
});

// Restore an already-issued legacy free term without adding credits or extending it.
router.post('/employers/:uid/migrate-free-term', async (req, res) => {
  try {
    const uid = req.params.uid;
    const database = catalogDb();
    const employerRef = database.collection('employers').doc(uid);
    const entitlementRef = database.collection('employer_entitlements').doc(uid);
    await database.runTransaction(async (tx) => {
      const [employer, entitlement] = await Promise.all([tx.get(employerRef), tx.get(entitlementRef)]);
      const profile = employer.data();
      if (entitlement.exists) throw Object.assign(new Error('Employer already has an entitlement.'), { status: 409 });
      if (profile?.status !== 'approved' || typeof profile.reviewedBy !== 'string' ||
          profile.reviewedBy.length === 0 ||
          (profile.reviewedAt?.toMillis?.() ?? 0) <= 0 ||
          profile.activePlan !== 'free_starter' ||
          profile.freeStarterUsed !== true ||
          typeof profile.creditsExpireAt?.toMillis !== 'function') {
        throw Object.assign(new Error('No reviewed legacy free term is eligible.'), { status: 409 });
      }
      tx.create(entitlementRef, {
        employerUid: uid, planId: 'free_starter', planVersion: 0,
        planName: profile.activePlanName || 'Free Starter', tier: 'free', reach: 'district',
        profileUnlockLimit: 0, unlocksUsed: 0, orderId: 'legacy_free_starter',
        startsAt: Timestamp.fromMillis(profile.creditsExpireAt.toMillis() - 7 * 86400000),
        expiresAt: profile.creditsExpireAt,
        migratedBy: req.user.uid, updatedAt: FieldValue.serverTimestamp(),
      });
      tx.create(database.collection('admin_audit').doc(), {
        action: 'legacy_free_migration', actorUid: req.user.uid,
        employerUid: uid, createdAt: FieldValue.serverTimestamp(),
      });
    });
    res.json({ status: 'migrated' });
  } catch (error) { fail(res, error); }
});

export default router;
