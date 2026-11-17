# Notifications

The bell icon opens the in-app notification inbox. It streams rows from the Supabase `notifications` table for the signed-in user, ordered by `created_at` (newest first). Each row includes `user_id`, `title`, `body`, `type`, `created_at`, and `is_read`. The recipient can mark one or all notifications as read. Protect these rows with Supabase RLS so users can access only their own notifications; trusted backend code creates them.

The mobile app initializes Firebase Messaging at startup without requesting notification permission or fetching an FCM token. Once a signed-in candidate completes onboarding and enters the portal, or an employer enters their workspace after registration, the app requests permission once. If allowed, it stores the device token on that user's Supabase `profiles` row. On later portal entries it registers an already-authorized token again, including after an account switch. A declined request is not repeated automatically; the user can enable notifications in device settings.

The backend uses Firebase Cloud Messaging for push delivery when FCM credentials are configured. In-app notifications are stored in Supabase; Firebase is used only for push delivery. The inbox displays its empty state until a trusted backend creates a notification.
