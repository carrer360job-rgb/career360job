import express from 'express';
import { getFirestore } from 'firebase-admin/firestore';
import { firebaseApp } from '../config/firebase.js';

const router = express.Router();
const publicKinds = new Set(['category', 'announcement']);

router.get('/', async (req, res) => {
  const kind = typeof req.query.kind === 'string' ? req.query.kind : '';
  if (!publicKinds.has(kind)) return res.status(400).json({ error: { message: 'Choose a valid content type.' } });
  if (!firebaseApp) return res.status(503).json({ error: { message: 'Platform content is unavailable.' } });
  try {
    const snapshot = await getFirestore(firebaseApp).collection('platform_content')
      .where('kind', '==', kind).limit(250).get();
    const items = snapshot.docs.filter((doc) => doc.data().active === true).map((doc) => ({ id: doc.id, title: doc.data().title || '',
      content: doc.data().content || '', sortOrder: doc.data().sortOrder || 0 }))
      .sort((a, b) => a.sortOrder - b.sortOrder || a.title.localeCompare(b.title));
    res.set('Cache-Control', 'public, max-age=60, stale-while-revalidate=300').json({ items });
  } catch (error) {
    console.error('[Public content]', error);
    res.status(503).json({ error: { message: 'Platform content is unavailable.' } });
  }
});

export default router;
