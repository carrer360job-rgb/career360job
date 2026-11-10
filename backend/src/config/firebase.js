import admin from 'firebase-admin';
import { getAuth } from 'firebase-admin/auth';
import { getApps, initializeApp, getApp } from 'firebase-admin/app';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

let firebaseApp = null;
let auth = null;

try {
  if (getApps().length > 0) {
    firebaseApp = getApp();
    auth = getAuth(firebaseApp);
  } else if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    // 1. From Environment Variable (Vercel / Cloud)
    let serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT;
    if (typeof serviceAccount === 'string') {
      try {
        serviceAccount = JSON.parse(serviceAccount);
      } catch (parseErr) {
        // In case env var has unescaped newlines or quotes
        serviceAccount = JSON.parse(serviceAccount.replace(/\\n/g, '\n'));
      }
    }
    firebaseApp = initializeApp({
      credential: admin.cert(serviceAccount)
    });
    auth = getAuth(firebaseApp);
    console.log('[Firebase Admin] Successfully initialized from FIREBASE_SERVICE_ACCOUNT env var.');
  } else {
    // 2. From Local File (Local development)
    const backendDir = path.resolve(__dirname, '../../');
    let keyPath = null;
    try {
      if (fs.existsSync(backendDir)) {
        const files = fs.readdirSync(backendDir);
        const matchedFile = files.find(f => 
          (f.includes('firebase-adminsdk') || f === 'firebase-service-account.json') && f.endsWith('.json')
        );
        if (matchedFile) {
          keyPath = path.join(backendDir, matchedFile);
        }
      }
    } catch (_) {}

    if (keyPath && fs.existsSync(keyPath)) {
      const serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
      firebaseApp = initializeApp({
        credential: admin.cert(serviceAccount)
      });
      auth = getAuth(firebaseApp);
      console.log(`[Firebase Admin] Successfully initialized from local ${path.basename(keyPath)}.`);
    } else {
      console.warn('[Firebase Admin] Notice: No Firebase service account configured. Operating in standalone mode.');
    }
  }
} catch (error) {
  console.error('[Firebase Admin Error]', error.message);
}

export { admin, firebaseApp, auth };
