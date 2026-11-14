# Employer release setup

The Android employer flow uses the same Firebase email/password and browser Google sign-in as the job seeker flow. An email can have one role only. Company registration requires a 10-digit contact number and a 10-digit WhatsApp number. Recruiters can choose to use the same number for both; the app keeps the two fields synchronized while that option is selected. These numbers are entered without phone OTP. Employer jobs and application decisions go through the backend; Firestore clients cannot grant approval, credits, or create jobs.

## Starter plan

The free starter draft grants one job credit once, after company approval. Its listing stays live for seven days. Plans and prices are stored in Firestore `employer_plans`; only admin-published versions are returned by `/api/employer/plans`. The initial drafts are Free Starter, Starter, Premium and Elite Tamil Nadu. Review and publish them in the admin website. No plan is sold from a client-side default catalog.

Paid terms have manual renewal. An active paid plan cannot be renewed until it expires; a paid plan may replace an active free starter. Applicant names, qualification and application status are visible in the employer's own applications. Contact details and photo require a server-authorized profile unlock from the active plan. Unlocks are counted once per candidate per plan term. The free starter has zero unlocks. Direct Firestore employer reads of application and public photo documents are denied by the updated rules.

## Firebase

1. In Firebase Console, enable **Authentication → Sign-in method → Email/Password** and **Google**. Add the Android app's SHA-1/SHA-256 fingerprints for Google sign-in if needed.
2. Publish the repository's [Firestore rules](../firestore.rules) in **Firestore Database → Rules**. Existing candidate access continues; employer approval, credits, payment records and jobs are protected from client writes. The repository does not deploy rules automatically.
3. Keep the Firebase service account credentials on the backend only. Never put them in the Flutter app or commit them.
4. Create a dedicated verified admin Firebase account. With the backend environment configured, run `node scripts/setAdminClaim.js admin@example.com --confirm` from `backend/`. Sign out and back in to refresh its ID token. The script rejects candidate and employer accounts. See [Admin web setup](ADMIN_WEB_SETUP.md).

## Razorpay

1. Create a Razorpay account and complete its business verification before live payments.
2. Add `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, and `RAZORPAY_WEBHOOK_SECRET` to the backend environment. Start with **test keys**. The secret keys must stay on the backend. `RAZORPAY_ENABLE_LIVE` must remain `false` for test mode.
3. In Razorpay Dashboard, register the webhook URL `https://YOUR_BACKEND/api/employer/payments/webhook` with **payment.captured**, **payment.refunded** and **refund.processed** events. Use the same webhook secret in the backend. The raw request body is used for signature verification. Enable automatic payment capture in Razorpay.
4. Deploy the updated backend, seed and publish plans in the admin website, then open `/api/employer/plans`. `checkoutReady` must be `true` before the app enables paid purchase. Keep `RAZORPAY_ENABLE_LIVE=false` during test mode.
5. Complete a test payment, confirm an `employer_orders` record becomes `paid`, an `employer_entitlements/{uid}` record appears, and the posting credit appears in `employers/{uid}`. Publish a job, apply with a separate candidate account, and verify a profile unlock spends one allowance. Repeat the captured webhook to confirm it does not add another credit. Test a full refund and confirm active access and the order are revoked.
6. Only after the end-to-end test and business approval, use live keys and set `RAZORPAY_ENABLE_LIVE=true` on the backend. Configure merchant legal details and an invoice process before charging customers; the app stores GST breakdowns in orders but does not issue a tax invoice. The release is currently intended for direct APK/private distribution; review Google Play billing rules before a future Play Store release.

## Review an employer

Company registration creates `employers/{uid}` with `status: pending`. A verified admin calls `GET /api/employer/admin/employers?status=pending` with its Firebase ID token. After checking the business details, the admin calls `POST /api/employer/admin/employers/{uid}/decision` with `{"decision":"approved"}` or `{"decision":"rejected"}`. The backend verifies the company's login email before approval and sends a notification. A rejected company cannot buy a plan or post a job. Only an admin claim can make this decision.

If a reviewed employer already received the old free starter credit before `employer_entitlements` existed, an admin can call `POST /api/admin/employers/{uid}/migrate-free-term`. It creates an entitlement with the original expiry and no additional credit. Check the employer record first; expired terms stay expired. This endpoint cannot migrate paid purchases.

## USB preview

Use `flutter run -d YOUR_DEVICE_ID` from `frontend/` to preview on an attached Android phone. Configure `API_BASE_URL` with `--dart-define` if testing a different backend. This work does not create a release APK; create one only after the USB preview is accepted.
