import express from 'express';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { auth, firebaseApp } from '../config/firebase.js';
import { verifyAdminToken } from '../middlewares/authMiddleware.js';
import { requireAdmin } from '../middlewares/adminMiddleware.js';
import { catalogDb, publicPlan, seedPlanDrafts, validatePlanDraft } from '../services/planCatalog.js';
import { revokeFullyRefundedOrder } from './employerRoutes.js';

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

async function razorpayAdminRequest(path, options = {}) {
  const keyId = process.env.RAZORPAY_KEY_ID || '';
  const secret = process.env.RAZORPAY_KEY_SECRET || '';
  const enabled = keyId.startsWith('rzp_test_') ||
    (keyId.startsWith('rzp_live_') && process.env.RAZORPAY_ENABLE_LIVE === 'true');
  if (!keyId || !secret || !enabled) throw Object.assign(new Error('Razorpay is not configured for this operation.'), { status: 503 });
  let response;
  try {
    response = await fetch(`https://api.razorpay.com/v1${path}`, {
      ...options,
      headers: { Authorization: `Basic ${Buffer.from(`${keyId}:${secret}`).toString('base64')}`,
        'Content-Type': 'application/json', ...options.headers },
      signal: AbortSignal.timeout(12000),
    });
  } catch {
    throw Object.assign(new Error('Razorpay response is uncertain. Refresh payment status before retrying.'), { status: 502 });
  }
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error('[Razorpay admin]', response.status, data.error?.code || 'unknown');
    throw Object.assign(new Error('Razorpay could not complete the request. Refresh the payment record.'), { status: 502 });
  }
  return data;
}

// 1. Platform Statistics Dashboard
router.get('/stats', async (req, res) => {
  try {
    const db = getFirestore(firebaseApp);
    const count = (collection, field, value) => {
      const base = db.collection(collection);
      return (field ? base.where(field, '==', value) : base).count().get();
    };
    const [totalCandidates, totalEmployers, pendingEmployers, approvedEmployers, rejectedEmployers,
      totalJobs, activeJobs, closedJobs, totalApplications] = await Promise.all([
      count('candidates'), count('employers'), count('employers', 'status', 'pending'),
      count('employers', 'status', 'approved'), count('employers', 'status', 'rejected'),
      count('jobs'), count('jobs', 'status', 'active'), count('jobs', 'status', 'closed'), count('applications'),
    ]);

    res.set('Cache-Control', 'no-store');
    res.json({
      totalCandidates: totalCandidates.data().count,
      totalEmployers: totalEmployers.data().count,
      pendingEmployers: pendingEmployers.data().count,
      approvedEmployers: approvedEmployers.data().count,
      rejectedEmployers: rejectedEmployers.data().count,
      totalJobs: totalJobs.data().count,
      activeJobs: activeJobs.data().count,
      closedJobs: closedJobs.data().count,
      totalApplications: totalApplications.data().count,
    });
  } catch (error) {
    fail(res, error);
  }
});

// 2. Employers List with Filtering
router.get('/employers', async (req, res) => {
  try {
    const db = getFirestore(firebaseApp);
    const statusFilter = ['pending', 'approved', 'rejected'].includes(req.query.status) ? req.query.status : 'all';
    const search = typeof req.query.search === 'string' ? req.query.search.trim().toLowerCase() : '';
    const cursorId = typeof req.query.cursor === 'string' ? req.query.cursor : '';

    let query = db.collection('employers');
    if (['pending', 'approved', 'rejected'].includes(statusFilter)) {
      query = query.where('status', '==', statusFilter);
    }
    query = query.orderBy('createdAt', 'desc');
    if (cursorId) {
      const cursor = await db.collection('employers').doc(cursorId).get();
      if (!cursor.exists) return res.status(400).json({ error: { message: 'Invalid employer page cursor.' } });
      query = query.startAfter(cursor);
    }
    const snap = await query.limit(51).get();
    const pageDocs = snap.docs.slice(0, 50);
    let employers = pageDocs.map((doc) => {
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
        activePlan: data.activePlan || '',
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
    res.json({ employers, nextCursor: snap.docs.length > 50 ? pageDocs.at(-1)?.id || null : null });
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
    const entitlementRef = db.collection('employer_entitlements').doc(uid);

    const result = await db.runTransaction(async (tx) => {
      const [employerDoc, entitlementDoc] = await Promise.all([tx.get(employerRef), tx.get(entitlementRef)]);
      if (!employerDoc.exists) {
        throw Object.assign(new Error('Employer account not found.'), { status: 404 });
      }
      const updates = {
        status: decision,
        reviewedBy: req.user.uid,
        reviewedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (decision === 'approved') {
        updates.rejectionReason = FieldValue.delete();
      } else {
        updates.rejectionReason = notes ? String(notes).trim().slice(0, 500) : 'Company verification could not be completed.';
        updates.postingCredits = 0;
        updates.creditsExpireAt = Timestamp.now();
        if (entitlementDoc.exists) tx.update(entitlementRef, {
          expiresAt: Timestamp.now(), revokedBy: req.user.uid, revokedAt: FieldValue.serverTimestamp(),
        });
      }

      tx.update(employerRef, updates);

      // In-app notification
      const notifRef = userRef.collection('notifications').doc();
      tx.create(notifRef, {
        title: decision === 'approved' ? 'Company Verified ✔️' : 'Company Verification Update',
        body: decision === 'approved'
          ? 'Your company profile has been approved. Choose a paid plan to publish jobs.'
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

    if (decision === 'rejected') {
      const activeJobs = await db.collection('jobs').where('employerUid', '==', uid).get();
      for (let offset = 0; offset < activeJobs.docs.length; offset += 450) {
        const page = activeJobs.docs.slice(offset, offset + 450).filter((job) => job.data().status === 'active');
        if (!page.length) continue;
        const batch = db.batch();
        page.forEach((job) => batch.update(job.ref, { status: 'closed', closedBy: 'admin_employer_review', closedAt: FieldValue.serverTimestamp() }));
        await batch.commit();
      }
    }

    res.json(result);
  } catch (error) {
    fail(res, error);
  }
});

// 4. Jobs Moderation List
router.get('/jobs', async (req, res) => {
  try {
    const db = getFirestore(firebaseApp);
    const status = ['active', 'closed'].includes(req.query.status) ? req.query.status : 'all';
    const search = typeof req.query.search === 'string' ? req.query.search.trim().toLowerCase() : '';
    const cursorId = typeof req.query.cursor === 'string' ? req.query.cursor : '';

    let query = db.collection('jobs');
    if (['active', 'closed'].includes(status)) {
      query = query.where('status', '==', status);
    }
    query = query.orderBy('postedAt', 'desc');

    if (cursorId) {
      const cursor = await db.collection('jobs').doc(cursorId).get();
      if (!cursor.exists) return res.status(400).json({ error: { message: 'Invalid job page cursor.' } });
      query = query.startAfter(cursor);
    }
    const snap = await query.limit(51).get();
    const pageDocs = snap.docs.slice(0, 50);
    let jobs = pageDocs.map((doc) => {
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
    res.json({ jobs, nextCursor: snap.docs.length > 50 ? pageDocs.at(-1)?.id || null : null });
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

router.get('/users', async (req, res) => {
  try {
    if (!auth) throw Object.assign(new Error('Firebase Authentication is unavailable.'), { status: 503 });
    const search = String(req.query.search || '').trim().toLowerCase();
    const db = getFirestore(firebaseApp);
    const page = await auth.listUsers(100, typeof req.query.pageToken === 'string' ? req.query.pageToken : undefined);
    const records = await Promise.all(page.users.map(async (user) => {
      const profile = await db.collection('users').doc(user.uid).get();
      const data = profile.data() || {};
      return {
        uid: user.uid, email: user.email || '', displayName: user.displayName || data.displayName || '',
        role: data.role === 'employer' ? 'employer' : data.role === 'candidate' ? 'candidate' : 'unassigned',
        disabled: user.disabled, emailVerified: user.emailVerified,
        createdAt: user.metadata.creationTime || null, lastSignInAt: user.metadata.lastSignInTime || null,
      };
    }));
    const filtered = search ? records.filter((u) =>
      u.email.toLowerCase().includes(search) || u.displayName.toLowerCase().includes(search) || u.uid.includes(search)) : records;
    res.set('Cache-Control', 'no-store').json({ users: filtered, nextPageToken: page.pageToken || null });
  } catch (error) { fail(res, error); }
});

router.post('/users/:uid/status', async (req, res) => {
  try {
    if (!auth) throw Object.assign(new Error('Firebase Authentication is unavailable.'), { status: 503 });
    const uid = req.params.uid;
    const disabled = req.body?.disabled;
    const reason = typeof req.body?.reason === 'string' ? req.body.reason.trim().slice(0, 300) : '';
    if (uid === req.user.uid) return res.status(400).json({ error: { message: 'You cannot suspend your own admin account.' } });
    if (typeof disabled !== 'boolean' || (disabled && reason.length < 5)) {
      return res.status(400).json({ error: { message: 'Choose a status and provide a short reason when suspending an account.' } });
    }
    const db = getFirestore(firebaseApp);
    await auth.updateUser(uid, { disabled });
    if (disabled) await auth.revokeRefreshTokens(uid);
    await db.collection('users').doc(uid).set({ accountDisabled: disabled, accountStatusUpdatedAt: FieldValue.serverTimestamp() }, { merge: true });
    if (disabled) {
      const jobs = await db.collection('jobs').where('employerUid', '==', uid).get();
      const activeJobs = jobs.docs.filter((job) => job.data().status === 'active');
      for (let offset = 0; offset < activeJobs.length; offset += 450) {
        const batch = db.batch();
        activeJobs.slice(offset, offset + 450).forEach((job) => batch.update(job.ref, {
          status: 'closed', closedBy: 'admin_suspension', closedAt: FieldValue.serverTimestamp(),
        }));
        await batch.commit();
      }
    }
    await db.collection('admin_audit').doc().create({
      action: disabled ? 'user_suspended' : 'user_activated', actorUid: req.user.uid,
      targetUid: uid, reason: reason || null, createdAt: FieldValue.serverTimestamp(),
    });
    res.json({ uid, disabled });
  } catch (error) { fail(res, error); }
});

router.get('/payments', async (req, res) => {
  try {
    const db = getFirestore(firebaseApp);
    const status = String(req.query.status || 'all');
    const validStatus = ['created', 'failed', 'paid', 'refunded'].includes(status) ? status : 'all';
    const cursorId = typeof req.query.cursor === 'string' ? req.query.cursor : '';
    let query = db.collection('employer_orders');
    if (validStatus !== 'all') query = query.where('status', '==', validStatus);
    query = query.orderBy('createdAt', 'desc');
    if (cursorId) {
      const cursor = await db.collection('employer_orders').doc(cursorId).get();
      if (!cursor.exists) return res.status(400).json({ error: { message: 'Invalid payment page cursor.' } });
      query = query.startAfter(cursor);
    }
    const snap = await query.limit(51).get();
    const pageDocs = snap.docs.slice(0, 50);
    const orders = pageDocs.map((doc) => {
      const data = doc.data();
      return { id: doc.id, employerUid: data.employerUid || '', planId: data.planId || '',
        planName: data.planName || '', amountPaise: data.amountPaise || 0, basePaise: data.basePaise || 0,
        taxPaise: data.taxPaise || 0, taxMode: data.taxMode || 'inclusive', taxRateBps: data.taxRateBps || 0,
        currency: data.currency || 'INR', status: data.status || 'created', paymentId: data.paymentId || null,
        createdAt: data.createdAt?.toDate?.()?.toISOString() || null,
        paidAt: data.paidAt?.toDate?.()?.toISOString() || null,
        refundedAt: data.refundedAt?.toDate?.()?.toISOString() || null,
        failedAt: data.failedAt?.toDate?.()?.toISOString() || null,
        failureCode: data.failureCode || null,
        refundStatus: data.refundStatus || null,
        refundReason: data.refundReason || null,
        refundRequestedAt: data.refundRequestedAt?.toDate?.()?.toISOString() || null };
    });
    res.set('Cache-Control', 'no-store').json({ payments: orders, nextCursor: snap.docs.length > 50 ? pageDocs.at(-1)?.id || null : null });
  } catch (error) { fail(res, error); }
});

router.post('/payments/:orderId/refund', async (req, res) => {
  try {
    const reason = typeof req.body?.reason === 'string' ? req.body.reason.trim().slice(0, 500) : '';
    if (reason.length < 5) return res.status(400).json({ error: { message: 'Enter a refund reason with at least five characters.' } });
    const database = getFirestore(firebaseApp);
    const orderRef = database.collection('employer_orders').doc(req.params.orderId);
    const orderSnapshot = await orderRef.get();
    const order = orderSnapshot.data();
    if (!orderSnapshot.exists || order?.status !== 'paid' || !order.paymentId) {
      return res.status(409).json({ error: { message: 'Only captured, non-refunded payments can be refunded.' } });
    }
    if (order.refundStatus && order.refundStatus !== 'failed') return res.status(409).json({ error: { message: 'A refund has already been requested for this order.' } });

    const payment = await razorpayAdminRequest(`/payments/${encodeURIComponent(order.paymentId)}`);
    if (payment.order_id !== req.params.orderId || payment.status !== 'captured' ||
        payment.amount !== order.amountPaise || payment.currency !== 'INR' || (payment.amount_refunded || 0) > 0) {
      return res.status(409).json({ error: { message: 'Razorpay payment details do not match an eligible full refund.' } });
    }
    await database.runTransaction(async (tx) => {
      const current = await tx.get(orderRef);
      if (current.data()?.status !== 'paid' || (current.data()?.refundStatus && current.data()?.refundStatus !== 'failed')) {
        throw Object.assign(new Error('This order is no longer eligible for a refund.'), { status: 409 });
      }
      tx.update(orderRef, { refundStatus: 'requested', refundReason: reason,
        refundRequestedBy: req.user.uid, refundRequestedAt: FieldValue.serverTimestamp(),
        refundAttempt: FieldValue.increment(1) });
    });
    await database.collection('admin_audit').doc().create({ action: 'payment_full_refund_requested',
      actorUid: req.user.uid, orderId: req.params.orderId, paymentId: payment.id, reason,
      createdAt: FieldValue.serverTimestamp() });

    // If Razorpay times out or returns an uncertain result, keep the request locked
    // and rely on a payment refresh/webhook instead of risking a second refund.
    const refund = await razorpayAdminRequest(`/payments/${encodeURIComponent(payment.id)}/refund`, {
      method: 'POST', body: JSON.stringify({ notes: { order_id: req.params.orderId, reason, requested_by: req.user.uid } }),
    });
    const latestPayment = await razorpayAdminRequest(`/payments/${encodeURIComponent(payment.id)}`);
    const fullyRefunded = latestPayment.amount > 0 && latestPayment.amount_refunded >= latestPayment.amount;
    if (fullyRefunded) await revokeFullyRefundedOrder(latestPayment);
    const refundStatus = fullyRefunded ? 'processed' : 'pending';
    await orderRef.update({ refundStatus, refundId: refund.id || null, refundUpdatedAt: FieldValue.serverTimestamp() });
    res.status(202).json({ status: refundStatus, refundId: refund.id || null });
  } catch (error) { fail(res, error); }
});

router.post('/payments/:orderId/reconcile', async (req, res) => {
  try {
    const database = getFirestore(firebaseApp);
    const orderRef = database.collection('employer_orders').doc(req.params.orderId);
    const orderSnapshot = await orderRef.get();
    const order = orderSnapshot.data();
    if (!orderSnapshot.exists || !order?.paymentId || !order.refundStatus) {
      return res.status(409).json({ error: { message: 'There is no pending refund request to reconcile.' } });
    }
    const paymentId = encodeURIComponent(order.paymentId);
    const [payment, refundList] = await Promise.all([
      razorpayAdminRequest(`/payments/${paymentId}`),
      razorpayAdminRequest(`/payments/${paymentId}/refunds`),
    ]);
    if (payment.order_id !== orderRef.id || payment.amount !== order.amountPaise || payment.currency !== 'INR') {
      return res.status(409).json({ error: { message: 'Razorpay payment does not match this order.' } });
    }
    let refundStatus = order.refundStatus;
    if (payment.amount > 0 && payment.amount_refunded >= payment.amount) {
      await revokeFullyRefundedOrder(payment);
      refundStatus = 'processed';
    } else if ((payment.amount_refunded || 0) > 0) {
      refundStatus = 'partial';
    } else {
      const refunds = Array.isArray(refundList.items) ? refundList.items : [];
      const latest = order.refundId
        ? refunds.find((item) => item.id === order.refundId)
        : refunds.sort((a, b) => (b.created_at || 0) - (a.created_at || 0))[0];
      if (latest?.status === 'failed') refundStatus = 'failed';
      else if (latest) refundStatus = 'pending';
    }
    await orderRef.update({ refundStatus, refundUpdatedAt: FieldValue.serverTimestamp() });
    res.json({ status: refundStatus });
  } catch (error) { fail(res, error); }
});

const contentKinds = new Set(['category', 'announcement']);
function contentPayload(body = {}) {
  const kind = body.kind;
  const title = typeof body.title === 'string' ? body.title.trim() : '';
  const content = typeof body.content === 'string' ? body.content.trim() : '';
  if (!contentKinds.has(kind) || title.length < 2 || title.length > 100 || content.length > 12000) {
    throw Object.assign(new Error('Enter a valid content type, title and content (up to 12,000 characters).'), { status: 400 });
  }
  return { kind, title, content, active: body.active !== false,
    sortOrder: Number.isInteger(body.sortOrder) ? Math.max(0, Math.min(1000, body.sortOrder)) : 0 };
}

router.get('/content', async (_req, res) => {
  try {
    const snap = await getFirestore(firebaseApp).collection('platform_content').limit(500).get();
    res.set('Cache-Control', 'no-store').json({ items: snap.docs.map((doc) => ({ id: doc.id, ...doc.data(),
      createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || null,
      updatedAt: doc.data().updatedAt?.toDate?.()?.toISOString() || null })) });
  } catch (error) { fail(res, error); }
});

router.post('/content', async (req, res) => {
  try {
    const payload = contentPayload(req.body);
    const db = getFirestore(firebaseApp);
    const ref = db.collection('platform_content').doc();
    await ref.create({ ...payload, createdBy: req.user.uid, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
    await db.collection('admin_audit').doc().create({ action: 'content_created', actorUid: req.user.uid,
      contentId: ref.id, kind: payload.kind, createdAt: FieldValue.serverTimestamp() });
    res.status(201).json({ id: ref.id, ...payload });
  } catch (error) { fail(res, error); }
});

router.put('/content/:id', async (req, res) => {
  try {
    const payload = contentPayload(req.body);
    const db = getFirestore(firebaseApp);
    const ref = db.collection('platform_content').doc(req.params.id);
    if (!(await ref.get()).exists) return res.status(404).json({ error: { message: 'Content item not found.' } });
    await ref.update({ ...payload, updatedBy: req.user.uid, updatedAt: FieldValue.serverTimestamp() });
    await db.collection('admin_audit').doc().create({ action: 'content_updated', actorUid: req.user.uid,
      contentId: ref.id, kind: payload.kind, createdAt: FieldValue.serverTimestamp() });
    res.json({ id: ref.id, ...payload });
  } catch (error) { fail(res, error); }
});

router.delete('/content/:id', async (req, res) => {
  try {
    const db = getFirestore(firebaseApp);
    const ref = db.collection('platform_content').doc(req.params.id);
    if (!(await ref.get()).exists) return res.status(404).json({ error: { message: 'Content item not found.' } });
    await ref.delete();
    await db.collection('admin_audit').doc().create({ action: 'content_deleted', actorUid: req.user.uid,
      contentId: ref.id, createdAt: FieldValue.serverTimestamp() });
    res.json({ status: 'deleted' });
  } catch (error) { fail(res, error); }
});

router.get('/reports', async (req, res) => {
  try {
    const db = getFirestore(firebaseApp);
    let reportsQuery = db.collection('job_reports').where('status', '==', 'pending').orderBy('createdAt', 'asc');
    const cursorId = typeof req.query.cursor === 'string' ? req.query.cursor : '';
    if (cursorId) {
      const cursor = await db.collection('job_reports').doc(cursorId).get();
      if (!cursor.exists) return res.status(400).json({ error: { message: 'Invalid report page cursor.' } });
      reportsQuery = reportsQuery.startAfter(cursor);
    }
    const [candidates, employers, jobs, applications, paid, pendingReports] = await Promise.all([
      db.collection('candidates').count().get(), db.collection('employers').count().get(),
      db.collection('jobs').count().get(), db.collection('applications').count().get(),
      db.collection('employer_orders').where('status', '==', 'paid').count().get(),
      reportsQuery.limit(51).get(),
    ]);
    const reports = pendingReports.docs.map((doc) => ({ id: doc.id, ...doc.data(),
      createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || null }));
    res.set('Cache-Control', 'no-store').json({ summary: { candidates: candidates.data().count,
      employers: employers.data().count, jobs: jobs.data().count, applications: applications.data().count,
      paidOrders: paid.data().count }, reports: reports.slice(0, 50),
      nextCursor: pendingReports.docs.length > 50 ? pendingReports.docs[49]?.id || null : null });
  } catch (error) { fail(res, error); }
});

router.post('/reports/:id/resolve', async (req, res) => {
  try {
    const decision = req.body?.decision;
    const notes = typeof req.body?.notes === 'string' ? req.body.notes.trim().slice(0, 500) : '';
    if (!['dismissed', 'job_closed'].includes(decision)) return res.status(400).json({ error: { message: 'Choose a valid report outcome.' } });
    const db = getFirestore(firebaseApp);
    const ref = db.collection('job_reports').doc(req.params.id);
    const report = await ref.get();
    if (!report.exists || report.data().status !== 'pending') return res.status(404).json({ error: { message: 'Pending report not found.' } });
    await db.runTransaction(async (tx) => {
      const current = await tx.get(ref);
      if (!current.exists || current.data().status !== 'pending') {
        throw Object.assign(new Error('This report has already been reviewed.'), { status: 409 });
      }
      const jobRef = current.data().jobId ? db.collection('jobs').doc(current.data().jobId) : null;
      const job = jobRef ? await tx.get(jobRef) : null;
      tx.update(ref, { status: decision, reviewedBy: req.user.uid, reviewedAt: FieldValue.serverTimestamp(), resolutionNotes: notes || null });
      if (decision === 'job_closed' && jobRef && job?.exists && job.data().status === 'active') {
        tx.update(jobRef, { status: 'closed', closedBy: 'admin_report_review', closedAt: FieldValue.serverTimestamp() });
      }
      tx.create(db.collection('admin_audit').doc(), { action: `job_report_${decision}`, actorUid: req.user.uid,
        reportId: ref.id, jobId: current.data().jobId || null, notes: notes || null, createdAt: FieldValue.serverTimestamp() });
    });
    res.json({ status: decision });
  } catch (error) { fail(res, error); }
});

// Plans Catalog Management
router.get('/plans', async (req, res) => {
  try {
    const snapshot = await catalogDb().collection('employer_plans').get();
    res.set('Cache-Control', 'no-store');
    res.json({ plans: snapshot.docs.filter((doc) => doc.data().draft?.tier !== 'free' && doc.data().published?.tier !== 'free').map((doc) => ({
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

export default router;
