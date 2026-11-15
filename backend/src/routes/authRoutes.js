import express from 'express';
import { verifySupabaseToken } from '../middlewares/authMiddleware.js';

const router = express.Router();

router.get('/me', verifySupabaseToken, (req, res) => {
  res.set('Cache-Control', 'no-store');
  res.json({ uid: req.user.uid, email: req.user.email, role: req.user.role,
    emailVerified: req.user.email_verified });
});

export default router;
