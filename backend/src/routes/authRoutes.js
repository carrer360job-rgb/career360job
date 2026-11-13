import express from 'express';
import {
  googleSync,
  syncProfile,
} from '../controllers/authController.js';

const router = express.Router();

// These endpoints are intentionally limited to Firebase identity synchronization.
// Email OTP endpoints were removed because the old implementation used predictable,
// stateless codes and in-memory rate limits. Use Firebase Auth verification instead.
router.post('/google-sync', googleSync);

// Profile Synchronization
router.post('/sync-profile', syncProfile);

export default router;
