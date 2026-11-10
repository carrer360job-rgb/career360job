import express from 'express';
import {
  sendEmailOtp,
  verifyEmailOtp,
  registerWithOtp,
  googleSync,
  sendForgotPasswordOtp,
  resetPasswordWithOtp,
  syncProfile,
} from '../controllers/authController.js';

const router = express.Router();

// Email OTP Endpoints
router.post('/email-otp/send', sendEmailOtp);
router.post('/email-otp/verify', verifyEmailOtp);
router.post('/register-with-otp', registerWithOtp);

// Google Sign-In Sync
router.post('/google-sync', googleSync);

// Forgot Password via OTP
router.post('/forgot-password/send-otp', sendForgotPasswordOtp);
router.post('/forgot-password/verify-reset', resetPasswordWithOtp);

// Profile Synchronization
router.post('/sync-profile', syncProfile);

export default router;
