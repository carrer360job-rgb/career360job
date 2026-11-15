import { supabaseAdmin } from '../config/supabase.js';
import { auth, firebaseApp } from '../config/firebase.js';

const verifyToken = (checkRevoked) => async (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      error: {
        message: 'Missing or malformed Authorization header. Expected Bearer <token>'
      }
    });
  }

  const token = authHeader.slice('Bearer '.length).trim();
  if (!token) {
    return res.status(401).json({ error: { message: 'Missing authentication token.' } });
  }

  // 1. Verify via Supabase Auth
  try {
    const { data, error } = await supabaseAdmin.auth.getUser(token);
    if (!error && data?.user) {
      const user = data.user;
      const isAdmin = user.email === 'carrer360job@gmail.com' ||
        user.app_metadata?.role === 'admin' ||
        user.user_metadata?.role === 'ADMIN';

      req.user = {
        uid: user.id,
        email: user.email,
        admin: isAdmin,
        role: isAdmin ? 'admin' : (user.user_metadata?.role || 'candidate'),
      };
      return next();
    }
  } catch (_) {
    // Continue to legacy fallback if any
  }

  // 2. Fallback verification via Firebase if legacy token provided
  if (auth && firebaseApp) {
    try {
      const decodedToken = await auth.verifyIdToken(token, checkRevoked);
      req.user = decodedToken;
      return next();
    } catch (_) {}
  }

  return res.status(401).json({
    error: {
      message: 'Invalid or expired authentication token',
      code: 'UNAUTHORIZED'
    }
  });
};

export const verifyFirebaseToken = verifyToken(false);
export const verifySensitiveToken = verifyToken(true);
export const verifyAdminToken = verifyToken(true);
