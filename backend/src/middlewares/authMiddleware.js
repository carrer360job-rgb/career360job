import { admin, firebaseApp } from '../config/firebase.js';

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
    return res.status(401).json({ error: { message: 'Missing Firebase ID token.' } });
  }

  if (!admin || !firebaseApp) {
    return res.status(503).json({
      error: {
        message: 'Firebase Authentication service is currently unavailable.'
      }
    });
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(token, checkRevoked);
    req.user = decodedToken;
    next();
  } catch (error) {
    console.error('[Auth Middleware] Token verification failed:', error.message);
    return res.status(401).json({
      error: {
        message: 'Invalid or expired authentication token',
        code: error.code || 'UNAUTHORIZED'
      }
    });
  }
};

export const verifyFirebaseToken = verifyToken(false);
export const verifyAdminToken = verifyToken(true);
