import express from 'express';
import { sendEmailOtp, verifyEmailOtp, registerWithOtp } from '../controllers/authController.js';

const router = express.Router();

// Email OTP Endpoints
router.post('/email-otp/send', sendEmailOtp);
router.post('/email-otp/verify', verifyEmailOtp);
router.post('/register-with-otp', registerWithOtp);

export default router;
