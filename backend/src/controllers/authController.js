import { auth } from '../config/firebase.js';
import { syncCandidateProfile } from '../config/db.js';

async function verifyFirebaseIdToken(idToken) {
  if (!auth) {
    const error = new Error('Firebase Authentication service is not configured.');
    error.status = 503;
    throw error;
  }

  try {
    return await auth.verifyIdToken(idToken);
  } catch {
    const error = new Error('Invalid or expired Firebase ID token.');
    error.status = 401;
    throw error;
  }
}

function sendError(res, error, context) {
  if (error.status === 401 || error.status === 503) {
    return res.status(error.status).json({ success: false, message: error.message });
  }

  console.error(`[${context}]`, error);
  return res.status(500).json({
    success: false,
    message: 'The profile could not be synchronized.',
  });
}

/** Synchronize a Firebase-authenticated user's profile to PostgreSQL. */
export async function googleSync(req, res) {
  try {
    const { idToken } = req.body;
    if (typeof idToken !== 'string' || !idToken) {
      return res.status(400).json({
        success: false,
        message: 'Firebase ID token is required.',
      });
    }

    const decoded = await verifyFirebaseIdToken(idToken);
    if (!decoded.email) {
      return res.status(400).json({ success: false, message: 'Verified account email is missing.' });
    }

    const profile = await syncCandidateProfile({
      firebaseUid: decoded.uid,
      email: decoded.email,
      fullName: decoded.name || decoded.email.split('@')[0],
      photoUrl: decoded.picture || null,
      isEmailVerified: decoded.email_verified === true,
    });

    return res.status(200).json({ success: true, user: profile.user });
  } catch (error) {
    return sendError(res, error, 'googleSync');
  }
}

/** Synchronize the currently authenticated Firebase user's profile. */
export async function syncProfile(req, res) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Missing or invalid Authorization header.',
      });
    }

    const decoded = await verifyFirebaseIdToken(authHeader.slice('Bearer '.length));
    if (!decoded.email) {
      return res.status(400).json({ success: false, message: 'Account email is missing.' });
    }

    const profile = await syncCandidateProfile({
      firebaseUid: decoded.uid,
      email: decoded.email,
      fullName: decoded.name || decoded.email.split('@')[0],
      photoUrl: decoded.picture || null,
      isEmailVerified: decoded.email_verified === true,
    });

    return res.status(200).json({ success: true, user: profile.user });
  } catch (error) {
    return sendError(res, error, 'syncProfile');
  }
}
