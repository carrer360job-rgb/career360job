import { admin, firebaseApp } from '../config/firebase.js';

export const verifyFirebaseToken = async (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      error: {
        message: 'Missing or malformed Authorization header. Expected Bearer <token>'
      }
    });
  }

  const token = authHeader.split('Bearer ')[1];

  if (!admin || !firebaseApp) {
    return res.status(503).json({
      error: {
        message: 'Firebase Authentication service is currently unavailable.'
      }
    });
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
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
