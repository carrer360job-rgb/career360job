import express from 'express';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
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
  console.error('[Admin plans]', error);
  return res.status(error.status || 500).json({ error: { message: error.status ? error.message : 'Plan request failed.' } });
}

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
