import { auth, firebaseApp } from '../config/firebase.js';
import { sendOtpEmail } from '../services/emailService.js';

// In-memory OTP store (email -> { otp, expiresAt, name, type, createdAt })
const otpStore = new Map();

/**
 * 1. Send 6-Digit Email OTP
 * POST /api/auth/email-otp/send
 */
export async function sendEmailOtp(req, res) {
  try {
    const { email, type = 'verification', name } = req.body;

    if (!email || !email.includes('@')) {
      return res.status(400).json({
        success: false,
        message: 'A valid email address is required.',
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    // Check rate limit: minimum 30 seconds between requests
    const existing = otpStore.get(normalizedEmail);
    if (existing && Date.now() - existing.createdAt < 30000) {
      const waitSec = Math.ceil((30000 - (Date.now() - existing.createdAt)) / 1000);
      return res.status(429).json({
        success: false,
        message: `Please wait ${waitSec}s before requesting a new code.`,
        retryAfter: waitSec,
      });
    }

    // Generate random 6-digit numeric OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = Date.now() + 10 * 60 * 1000; // 10 minutes

    otpStore.set(normalizedEmail, {
      otp,
      expiresAt,
      name: name || existing?.name || null,
      type,
      createdAt: Date.now(),
    });

    // Send email
    await sendOtpEmail({
      to: normalizedEmail,
      otp,
      type,
    });

    return res.status(200).json({
      success: true,
      message: 'Verification code sent to your email.',
      email: normalizedEmail,
      expiresInMinutes: 10,
      resendWaitSeconds: 45,
    });
  } catch (error) {
    console.error('[sendEmailOtp Error]', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to send verification email. Please try again.',
      error: error.message,
    });
  }
}

/**
 * 2. Verify 6-Digit Email OTP
 * POST /api/auth/email-otp/verify
 */
export async function verifyEmailOtp(req, res) {
  try {
    const { email, otp, name, password } = req.body;

    if (!email || !otp) {
      return res.status(400).json({
        success: false,
        message: 'Both email and verification code are required.',
      });
    }

    const normalizedEmail = email.trim().toLowerCase();
    const record = otpStore.get(normalizedEmail);

    if (!record) {
      return res.status(400).json({
        success: false,
        message: 'No verification session found. Please request a new code.',
      });
    }

    if (Date.now() > record.expiresAt) {
      otpStore.delete(normalizedEmail);
      return res.status(400).json({
        success: false,
        message: 'Verification code has expired. Please request a new one.',
      });
    }

    if (record.otp !== otp.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Invalid verification code. Please check your inbox and try again.',
      });
    }

    // OTP is valid! Clean up store
    otpStore.delete(normalizedEmail);

    let customToken = null;
    let firebaseUser = null;

    // If Firebase Admin is available, create or fetch user & generate custom token
    if (auth) {
      try {
        try {
          firebaseUser = await auth.getUserByEmail(normalizedEmail);
        } catch (notFoundErr) {
          // User doesn't exist in Firebase yet, create new user
          firebaseUser = await auth.createUser({
            email: normalizedEmail,
            emailVerified: true,
            displayName: name || record.name || normalizedEmail.split('@')[0],
            password: password || undefined,
          });
        }

        // Ensure email is marked verified
        if (!firebaseUser.emailVerified) {
          await auth.updateUser(firebaseUser.uid, { emailVerified: true });
        }

        customToken = await auth.createCustomToken(firebaseUser.uid);
      } catch (fbErr) {
        console.error('[Firebase Custom Token Error]', fbErr.message);
      }
    }

    return res.status(200).json({
      success: true,
      message: 'Email successfully verified!',
      customToken,
      user: {
        email: normalizedEmail,
        displayName: name || record.name || null,
        uid: firebaseUser?.uid || null,
      },
    });
  } catch (error) {
    console.error('[verifyEmailOtp Error]', error);
    return res.status(500).json({
      success: false,
      message: 'Verification failed. Please try again.',
      error: error.message,
    });
  }
}

/**
 * 3. Initiate Sign Up with Email OTP
 * POST /api/auth/register-with-otp
 */
export async function registerWithOtp(req, res) {
  try {
    const { name, email, password } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Full name, email, and password are required.',
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters long.',
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    // Generate OTP & store registration payload
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = Date.now() + 10 * 60 * 1000;

    otpStore.set(normalizedEmail, {
      otp,
      expiresAt,
      name: name.trim(),
      type: 'signup',
      createdAt: Date.now(),
    });

    await sendOtpEmail({
      to: normalizedEmail,
      otp,
      type: 'signup',
    });

    return res.status(200).json({
      success: true,
      message: 'Account created! Verification code sent to your email.',
      email: normalizedEmail,
      resendWaitSeconds: 45,
    });
  } catch (error) {
    console.error('[registerWithOtp Error]', error);
    return res.status(500).json({
      success: false,
      message: 'Sign up failed. Please try again.',
      error: error.message,
    });
  }
}
