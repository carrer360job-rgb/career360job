import admin from 'firebase-admin';
import { getApps, initializeApp, getApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { supabaseAdmin } from '../config/supabase.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

let fcmMessaging = null;

// Initialize Firebase Messaging exclusively for push notifications
try {
  const existingApps = getApps();
  if (existingApps.length > 0) {
    fcmMessaging = getMessaging(existingApps[0]);
  } else if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    const creds = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    const app = initializeApp({ credential: admin.cert(creds) });
    fcmMessaging = getMessaging(app);
    console.log('[FCM Service] Initialized from FIREBASE_SERVICE_ACCOUNT environment variable.');
  } else if (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_CLIENT_EMAIL && process.env.FIREBASE_PRIVATE_KEY) {
    const app = initializeApp({
      credential: admin.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
      }),
    });
    fcmMessaging = getMessaging(app);
    console.log('[FCM Service] Initialized from individual Firebase environment variables.');
  } else {
    // Check for local service account JSON in backend folder (development)
    const backendRoot = path.resolve(__dirname, '../../');
    const files = fs.readdirSync(backendRoot);
    const keyFile = files.find((f) => f.includes('firebase-adminsdk') && f.endsWith('.json'));
    if (keyFile) {
      const fullPath = path.join(backendRoot, keyFile);
      const creds = JSON.parse(fs.readFileSync(fullPath, 'utf8'));
      const app = initializeApp({ credential: admin.cert(creds) });
      fcmMessaging = getMessaging(app);
      console.log(`[FCM Service] Initialized locally from ${keyFile} for project: ${creds.project_id}`);
    } else {
      console.warn('[FCM Service] Standby mode: No FCM credentials configured. In-app Supabase notifications remain active.');
    }
  }
} catch (error) {
  console.warn('[FCM Service Warning] Initialization skipped:', error.message);
}

/**
 * Send push notification to a single FCM device token
 */
export async function sendPushNotification({ token, title, body, data = {} }) {
  if (!token) return { success: false, reason: 'missing_token' };
  if (!fcmMessaging) {
    console.log(`[FCM Standby] Push queued for token: ${token.slice(0, 12)}... Title: "${title}"`);
    return { success: false, reason: 'fcm_not_configured' };
  }

  try {
    const message = {
      token,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, typeof v === 'string' ? v : JSON.stringify(v)])
      ),
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'career360_alerts',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: { sound: 'default', badge: 1 },
        },
      },
    };

    const response = await fcmMessaging.send(message);
    return { success: true, messageId: response };
  } catch (error) {
    console.error('[FCM Send Error]', error.message);
    return { success: false, error: error.message };
  }
}

/**
 * Send push notification to multiple device tokens
 */
export async function sendMulticastNotification({ tokens, title, body, data = {} }) {
  const validTokens = (tokens || []).filter(Boolean);
  if (!validTokens.length) return { success: false, reason: 'no_tokens' };

  if (!fcmMessaging) {
    console.log(`[FCM Standby] Multicast queued for ${validTokens.length} devices. Title: "${title}"`);
    return { success: false, reason: 'fcm_not_configured' };
  }

  try {
    const message = {
      tokens: validTokens,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, typeof v === 'string' ? v : JSON.stringify(v)])
      ),
    };

    const response = await fcmMessaging.sendEachForMulticast(message);
    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (error) {
    console.error('[FCM Multicast Error]', error.message);
    return { success: false, error: error.message };
  }
}

/**
 * High-level helper:
 * 1. Inserts the notification into Supabase `notifications` table (for in-app bell & realtime).
 * 2. Fetches recipient's `fcm_token` from Supabase `profiles`.
 * 3. Sends FCM lock-screen push notification.
 */
export async function sendNotificationToUser({ userId, title, body, type = 'GENERAL', metadata = {} }) {
  if (!userId) return { success: false, reason: 'missing_user_id' };

  // 1. Record in Supabase notifications table
  try {
    await supabaseAdmin.from('notifications').insert({
      user_id: userId,
      title,
      body,
      type,
      data: metadata,
      is_read: false,
    });
  } catch (dbErr) {
    console.error('[Supabase Notification Log Error]', dbErr.message);
  }

  // 2. Lookup recipient's FCM token from Supabase profiles
  try {
    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('fcm_token')
      .eq('id', userId)
      .maybeSingle();

    if (profile?.fcm_token) {
      return await sendPushNotification({
        token: profile.fcm_token,
        title,
        body,
        data: { type, userId, ...metadata },
      });
    }
  } catch (tokenErr) {
    console.error('[FCM Token Lookup Error]', tokenErr.message);
  }

  return { success: true, deliveredInAppOnly: true };
}

export default {
  sendPushNotification,
  sendMulticastNotification,
  sendNotificationToUser,
};
