import crypto from 'crypto';
import { auth } from '../config/firebase.js';
import { syncCandidateProfile } from '../config/db.js';
import { sendOtpEmail } from '../services/emailService.js';

const OTP_SECRET = process.env.JWT_ACCESS_SECRET || 'career360_secure_otp_secret_key_2026';
const OTP_WINDOW_MS = 10 * 60 * 1000; // 10-minute valid window

/**
 * Deterministically derive an HMAC-based 6-digit OTP from email and time-window slot.
 * Guarantees zero-database, serverless-safe verification even if client does not return a token.
 */
function deriveOtp(email, slot) {
  const h = crypto
    .createHmac('sha256', OTP_SECRET)
    .update(`${email.toLowerCase().trim()}:${slot}`)
    .digest('hex');
  const num = (parseInt(h.substring(0, 8), 16) % 900000) + 100000;
  return num.toString();
}

/**
 * Verify derived OTP against current and previous time window (up to 20 mins total grace period).
 */
function verifyDerivedOtp(email, candidateOtp) {
  if (!candidateOtp) return false;
  const normalized = email.toLowerCase().trim();
  const currentSlot = Math.floor(Date.now() / OTP_WINDOW_MS);
  const trimmed = candidateOtp.toString().trim();

  // Check current window and previous window (clock skew tolerance)
  return trimmed === deriveOtp(normalized, currentSlot) || trimmed === deriveOtp(normalized, currentSlot - 1);
}

/**
 * Generate a cryptographically signed, stateless verification token.
 * Guarantees zero-failure verification on stateless serverless functions (e.g. Vercel).
 */
function generateVerificationToken({ email, otp, expiresAt, name, type }) {
  const payload = `${email}:${otp}:${expiresAt}`;
  const hash = crypto.createHmac('sha256', OTP_SECRET).update(payload).digest('hex');
  const tokenData = JSON.stringify({ email, expiresAt, hash, name, type });
  return Buffer.from(tokenData).toString('base64url');
}

/**
 * Verify a stateless verification token with constant-time equality.
 */
function verifyVerificationToken({ token, email, otp, expectedType }) {
  try {
    const jsonStr = Buffer.from(token, 'base64url').toString('utf8');
    const { email: tokenEmail, expiresAt, hash, name, type } = JSON.parse(jsonStr);

    if (tokenEmail !== email.toLowerCase().trim()) {
      return { valid: false, message: 'Verification email mismatch.' };
    }
    if (Date.now() > expiresAt) {
      return { valid: false, message: 'Verification code has expired. Please request a new one.' };
    }
    if (expectedType && type && type !== expectedType) {
      return { valid: false, message: 'Invalid verification session type.' };
    }

    const payload = `${tokenEmail}:${otp.trim()}:${expiresAt}`;
    const expectedHash = crypto.createHmac('sha256', OTP_SECRET).update(payload).digest('hex');

    const a = Buffer.from(hash, 'hex');
    const b = Buffer.from(expectedHash, 'hex');
    if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
      return { valid: false, message: 'Invalid verification code. Please check your inbox and try again.' };
    }

    return { valid: true, name, type };
  } catch (err) {
    return { valid: false, message: 'Invalid or malformed verification session.' };
  }
}

// In-memory fallback OTP store (email -> { otp, expiresAt, name, password, type, createdAt })
const otpStore = new Map();

/**
 * Clean up expired OTPs periodically (every 10 minutes)
 */
setInterval(() => {
  const now = Date.now();
  for (const [email, record] of otpStore.entries()) {
    if (now > record.expiresAt) {
      otpStore.delete(email);
    }
  }
}, 10 * 60 * 1000).unref?.();

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

    // Generate cryptographically derived 6-digit numeric OTP (stateless)
    const currentSlot = Math.floor(Date.now() / OTP_WINDOW_MS);
    const otp = deriveOtp(normalizedEmail, currentSlot);
    const expiresAt = Date.now() + OTP_WINDOW_MS;

    otpStore.set(normalizedEmail, {
      otp,
      expiresAt,
      name: name || existing?.name || null,
      password: existing?.password || null,
      type,
      createdAt: Date.now(),
    });

    // Send email
    const emailRes = await sendOtpEmail({
      to: normalizedEmail,
      otp,
      type,
      name: name || existing?.name || null,
    });

    if (emailRes.success === false && !emailRes.devMode) {
      otpStore.delete(normalizedEmail);
      return res.status(400).json({
        success: false,
        message: emailRes.error || 'Failed to deliver verification email.',
      });
    }

    const verificationToken = generateVerificationToken({
      email: normalizedEmail,
      otp,
      expiresAt,
      name: name || existing?.name || null,
      type,
    });

    return res.status(200).json({
      success: true,
      message: 'Verification code sent to your email.',
      email: normalizedEmail,
      verificationToken,
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
    const { email, otp, verificationToken, name, password } = req.body;

    if (!email || !otp) {
      return res.status(400).json({
        success: false,
        message: 'Both email and verification code are required.',
      });
    }

    const normalizedEmail = email.trim().toLowerCase();
    let resolvedName = name || normalizedEmail.split('@')[0];
    let resolvedPassword = password;

    const isCryptoMatch = verifyDerivedOtp(normalizedEmail, otp);
    let isTokenMatch = false;

    if (verificationToken) {
      const tokenResult = verifyVerificationToken({
        token: verificationToken,
        email: normalizedEmail,
        otp,
      });

      if (tokenResult.valid) {
        isTokenMatch = true;
        if (tokenResult.name && !name) {
          resolvedName = tokenResult.name;
        }
      }
    }

    const record = otpStore.get(normalizedEmail);
    const isStoreMatch = record && record.otp === otp.trim() && Date.now() <= record.expiresAt;
    if (record) {
      resolvedName = name || record.name || resolvedName;
      resolvedPassword = password || record.password;
    }

    if (!isCryptoMatch && !isTokenMatch && !isStoreMatch) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or expired verification code. Please check your inbox or request a new one.',
      });
    }

    // Clean up OTP session
    otpStore.delete(normalizedEmail);

    let customToken = null;
    let firebaseUser = null;

    // Firebase Admin Integration
    if (auth) {
      try {
        try {
          firebaseUser = await auth.getUserByEmail(normalizedEmail);
          // If password was supplied, update user password
          if (resolvedPassword && resolvedPassword.length >= 6) {
            await auth.updateUser(firebaseUser.uid, {
              password: resolvedPassword,
              emailVerified: true,
              displayName: resolvedName,
            });
          } else {
            await auth.updateUser(firebaseUser.uid, { emailVerified: true });
          }
        } catch (notFoundErr) {
          // User doesn't exist yet, create new Firebase user
          firebaseUser = await auth.createUser({
            email: normalizedEmail,
            emailVerified: true,
            displayName: resolvedName,
            password: resolvedPassword || undefined,
          });
        }

        customToken = await auth.createCustomToken(firebaseUser.uid);
      } catch (fbErr) {
        console.error('[Firebase Custom Token Error]', fbErr.message);
      }
    }

    // Sync profile to database
    const dbSync = await syncCandidateProfile({
      firebaseUid: firebaseUser?.uid || null,
      email: normalizedEmail,
      fullName: resolvedName,
      isEmailVerified: true,
    });

    return res.status(200).json({
      success: true,
      message: 'Email successfully verified!',
      customToken,
      user: {
        uid: firebaseUser?.uid || null,
        email: normalizedEmail,
        displayName: resolvedName,
        role: dbSync.user?.role || 'CANDIDATE',
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

    if (password.length < 8) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 8 characters long.',
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    // Generate OTP & store registration payload
    const currentSlot = Math.floor(Date.now() / OTP_WINDOW_MS);
    const otp = deriveOtp(normalizedEmail, currentSlot);
    const expiresAt = Date.now() + OTP_WINDOW_MS;

    otpStore.set(normalizedEmail, {
      otp,
      expiresAt,
      name: name.trim(),
      password,
      type: 'signup',
      createdAt: Date.now(),
    });

    const emailRes = await sendOtpEmail({
      to: normalizedEmail,
      otp,
      type: 'signup',
      name: name.trim(),
    });

    if (emailRes.success === false && !emailRes.devMode) {
      otpStore.delete(normalizedEmail);
      return res.status(400).json({
        success: false,
        message: emailRes.error || 'Failed to deliver verification email.',
      });
    }

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

/**
 * 4. Google Sign-In Profile Synchronization
 * POST /api/auth/google-sync
 */
export async function googleSync(req, res) {
  try {
    const { idToken } = req.body;

    if (!idToken) {
      return res.status(400).json({
        success: false,
        message: 'Firebase idToken is required for Google synchronization.',
      });
    }

    let decodedToken = null;
    if (auth) {
      try {
        decodedToken = await auth.verifyIdToken(idToken);
      } catch (tokenErr) {
        return res.status(401).json({
          success: false,
          message: 'Invalid or expired Google authentication token.',
          error: tokenErr.message,
        });
      }
    } else {
      // In dev fallback, extract unverified payload if available
      try {
        const payloadBase64 = idToken.split('.')[1];
        decodedToken = JSON.parse(Buffer.from(payloadBase64, 'base64').toString('utf8'));
      } catch (_) {}
    }

    const firebaseUid = decodedToken?.uid || decodedToken?.sub;
    const email = decodedToken?.email;
    const fullName = decodedToken?.name || email?.split('@')[0] || 'Google User';
    const photoUrl = decodedToken?.picture || null;

    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'No email found in Google authentication token.',
      });
    }

    // Sync profile to database
    const dbSync = await syncCandidateProfile({
      firebaseUid,
      email,
      fullName,
      photoUrl,
      isEmailVerified: true,
    });

    return res.status(200).json({
      success: true,
      message: 'Google profile synchronized successfully.',
      user: {
        uid: firebaseUid,
        email,
        displayName: fullName,
        photoUrl,
        role: dbSync.user?.role || 'CANDIDATE',
      },
    });
  } catch (error) {
    console.error('[googleSync Error]', error);
    return res.status(500).json({
      success: false,
      message: 'Google sync failed. Please try again.',
      error: error.message,
    });
  }
}

/**
 * 5. Forgot Password - Send OTP
 * POST /api/auth/forgot-password/send-otp
 */
export async function sendForgotPasswordOtp(req, res) {
  try {
    const { email } = req.body;

    if (!email || !email.includes('@')) {
      return res.status(400).json({
        success: false,
        message: 'A valid email address is required.',
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    // Check if user exists in Firebase Admin (if connected)
    if (auth) {
      try {
        await auth.getUserByEmail(normalizedEmail);
      } catch (notFound) {
        return res.status(404).json({
          success: false,
          message: 'No Career360 account exists with this email address.',
        });
      }
    }

    const currentSlot = Math.floor(Date.now() / OTP_WINDOW_MS);
    const otp = deriveOtp(normalizedEmail, currentSlot);
    const expiresAt = Date.now() + OTP_WINDOW_MS;

    otpStore.set(normalizedEmail, {
      otp,
      expiresAt,
      type: 'password_reset',
      createdAt: Date.now(),
    });

    const emailRes = await sendOtpEmail({
      to: normalizedEmail,
      otp,
      type: 'password_reset',
    });

    if (emailRes.success === false && !emailRes.devMode) {
      otpStore.delete(normalizedEmail);
      return res.status(400).json({
        success: false,
        message: emailRes.error || 'Failed to deliver password reset code.',
      });
    }

    const verificationToken = generateVerificationToken({
      email: normalizedEmail,
      otp,
      expiresAt,
      type: 'password_reset',
    });

    return res.status(200).json({
      success: true,
      message: 'Password reset code sent to your email.',
      email: normalizedEmail,
      verificationToken,
      resendWaitSeconds: 45,
    });
  } catch (error) {
    console.error('[sendForgotPasswordOtp Error]', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to send password reset code. Please try again.',
      error: error.message,
    });
  }
}

/**
 * 6. Forgot Password - Verify OTP & Update Password
 * POST /api/auth/forgot-password/verify-reset
 */
export async function resetPasswordWithOtp(req, res) {
  try {
    const { email, otp, verificationToken, newPassword } = req.body;

    if (!email || !otp || !newPassword) {
      return res.status(400).json({
        success: false,
        message: 'Email, verification code, and new password are required.',
      });
    }

    if (newPassword.length < 8) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 8 characters long.',
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    const isCryptoMatch = verifyDerivedOtp(normalizedEmail, otp);
    let isTokenMatch = false;

    if (verificationToken) {
      const tokenResult = verifyVerificationToken({
        token: verificationToken,
        email: normalizedEmail,
        otp,
        expectedType: 'password_reset',
      });

      if (tokenResult.valid) {
        isTokenMatch = true;
      }
    }

    const record = otpStore.get(normalizedEmail);
    const isStoreMatch = record && record.type === 'password_reset' && record.otp === otp.trim() && Date.now() <= record.expiresAt;

    if (!isCryptoMatch && !isTokenMatch && !isStoreMatch) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or expired verification code. Please request a new code.',
      });
    }

    // Code verified! Remove from store
    otpStore.delete(normalizedEmail);

    // Update password in Firebase
    if (auth) {
      try {
        const user = await auth.getUserByEmail(normalizedEmail);
        await auth.updateUser(user.uid, {
          password: newPassword,
        });
      } catch (fbErr) {
        console.error('[Firebase Password Reset Error]', fbErr.message);
        return res.status(500).json({
          success: false,
          message: 'Failed to update password in Firebase: ' + fbErr.message,
        });
      }
    }

    return res.status(200).json({
      success: true,
      message: 'Password has been successfully reset! You can now sign in.',
    });
  } catch (error) {
    console.error('[resetPasswordWithOtp Error]', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to reset password. Please try again.',
      error: error.message,
    });
  }
}

/**
 * 7. Sync & Get Current Authenticated Profile
 * POST /api/auth/sync-profile
 */
export async function syncProfile(req, res) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Missing or invalid Authorization header.',
      });
    }

    const token = authHeader.split('Bearer ')[1];
    let decodedToken = null;

    if (auth) {
      try {
        decodedToken = await auth.verifyIdToken(token);
      } catch (err) {
        return res.status(401).json({
          success: false,
          message: 'Invalid or expired Firebase ID token.',
        });
      }
    } else {
      try {
        const payloadBase64 = token.split('.')[1];
        decodedToken = JSON.parse(Buffer.from(payloadBase64, 'base64').toString('utf8'));
      } catch (_) {}
    }

    const firebaseUid = decodedToken?.uid || decodedToken?.sub;
    const email = decodedToken?.email;
    const fullName = decodedToken?.name || email?.split('@')[0] || 'Candidate';
    const photoUrl = decodedToken?.picture || null;

    const dbSync = await syncCandidateProfile({
      firebaseUid,
      email,
      fullName,
      photoUrl,
      isEmailVerified: decodedToken?.email_verified ?? true,
    });

    return res.status(200).json({
      success: true,
      user: {
        uid: firebaseUid,
        email,
        displayName: fullName,
        photoUrl,
        role: dbSync.user?.role || 'CANDIDATE',
      },
    });
  } catch (error) {
    console.error('[syncProfile Error]', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to sync profile.',
      error: error.message,
    });
  }
}
