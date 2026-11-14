import { getApp, getApps, initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';

const config = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY?.trim(),
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN?.trim(),
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID?.trim(),
  appId: import.meta.env.VITE_FIREBASE_APP_ID?.trim(),
};

export const missingConfiguration = [
  ...Object.entries(config).filter(([, value]) => !value).map(([key]) => key),
  ...(!import.meta.env.VITE_API_BASE_URL?.trim() ? ['API_BASE_URL'] : []),
];

export const auth = missingConfiguration.length === 0
  ? getAuth(getApps().length > 0 ? getApp() : initializeApp(config))
  : null;
