# Career360 admin web setup

The admin website lives in `admin-web/`. It uses Firebase Authentication for email/password sign-in and the existing Express backend for authorization. Its dashboard manages users, employers, jobs, paid plans, payment records, categories, announcements, and job reports.

## Firebase setup

1. In the same Firebase project used by the Android app, register a **Web app** in Firebase Console → Project settings → Your apps. Copy its web configuration into `admin-web/.env.local`, using `admin-web/.env.example` as a template. These `VITE_` values are browser configuration, not Firebase Admin SDK secrets.
2. In Firebase Console → Authentication → Sign-in method, enable **Email/Password**. In Authentication → Settings → Authorized domains, add the admin website's domain when it is deployed.
3. Create a **separate** Firebase Authentication user for the admin. Do not reuse a candidate or employer account. Verify its email address.
4. With backend Firebase Admin credentials configured, run `node scripts/setAdminClaim.js admin@example.com --confirm` from `backend/`. The script refuses unverified emails, non-password accounts, and candidate or employer accounts. Sign out and sign back in after the claim is granted so Firebase issues a fresh ID token.
5. Publish the updated repository `firestore.rules` in Firebase Console → Firestore Database → Rules. Employer registration now creates a `pending` profile; clients cannot mark it approved or grant themselves posting credits.

The admin password and Firebase service account private key must never be placed in `admin-web/` or committed to Git.

## Local preview

1. Copy `admin-web/.env.example` to `admin-web/.env.local` and enter the Firebase **web app** values. Set `VITE_API_BASE_URL=http://localhost:5000` for a local backend or the deployed backend URL for a remote test.
2. Set `CLIENT_URL_ADMIN=http://localhost:5173` in the backend environment. Start the backend with `npm run dev` from `backend/`.
3. Run `npm install` and `npm run dev` from `admin-web/`, then open the Vite URL. There is no admin sign-up page.

`GET /api/admin/me` requires a Firebase ID token with a verified email and `admin: true` claim. The backend checks token revocation and returns only the admin UID, email and role. Missing tokens return 401; ordinary signed-in users return 403.

The website opens its dashboard only after this backend check succeeds. It uses the configured `VITE_API_BASE_URL` for every admin request and does not try another backend if that one is unavailable. Admin sign-in persists for the current browser tab session; closing the tab clears it.

## Vercel deployment

Deploy `admin-web/` as a **separate Vercel project** with root directory `admin-web`, build command `npm run build`, and output directory `dist`. Set all five `VITE_` variables in that project's environment; `VITE_API_BASE_URL` should point to the deployed backend. Set `CLIENT_URL_ADMIN` in the backend project's environment to the admin website's exact HTTPS origin (no trailing slash), then redeploy the backend. Add the admin website hostname to Firebase Authentication's authorized domains.

The web app will show a setup message until the required configuration is present. No admin account, Firebase web app, or production deployment is created automatically by this repository.

## Payments and refunds

The Payments tab lists paid, pending, failed, and refunded orders with their GST breakdown. An administrator can request a **full refund** for a captured payment with a recorded reason, then reconcile a delayed Razorpay response. The server locks an order against duplicate refund requests and revokes the associated entitlement only after Razorpay confirms the full refund. Test this flow with Razorpay test credentials before enabling live payments.

## Plan management

Sign in to the admin website, choose **Create starter drafts**, review each plan's price and GST rate, save its draft, and then publish it. Drafts are invisible to employers. Published plans appear in the Android app immediately. Each publish creates an immutable version record; existing Razorpay orders keep their original price, tax and benefits. Archive hides a plan from new purchases without changing past orders.

The draft prices and 18% GST setting are examples, not a determination of the applicable tax rate. Confirm the taxable supply, rate, invoice details and merchant GST registration with your accountant before publishing a paid plan. The admin form uses paise and basis points: `236000` means ₹2,360 and `1800` means 18%. Choose whether the entered price includes GST or has GST added at checkout. The preview shows the customer total before publication.

## Employer review during this first release

New employer registrations remain `pending` until an authorized admin reviews them in the Companies tab. The admin website also manages candidate/employer accounts, jobs, paid plans, payment records, platform content, and job reports. Employer actions require the trusted review record; an older `approved` profile without `reviewedBy` and `reviewedAt` must be reviewed again. Approval never grants job-posting credits; employers need an active paid entitlement.
