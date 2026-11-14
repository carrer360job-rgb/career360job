# Career360 admin web setup

The admin website lives in `admin-web/`. It uses Firebase Authentication for email/password sign-in and the existing Express backend for authorization. The first dashboard intentionally contains no management tools.

## Firebase setup

1. In the same Firebase project used by the Android app, register a **Web app** in Firebase Console → Project settings → Your apps. Copy its web configuration into `admin-web/.env.local`, using `admin-web/.env.example` as a template. These `VITE_` values are browser configuration, not Firebase Admin SDK secrets.
2. In Firebase Console → Authentication → Sign-in method, enable **Email/Password**. In Authentication → Settings → Authorized domains, add the admin website's domain when it is deployed.
3. Create a **separate** Firebase Authentication user for the admin. Do not reuse a candidate or employer account. Verify its email address.
4. With backend Firebase Admin credentials configured, run `node scripts/setAdminClaim.js admin@example.com --confirm` from `backend/`. The script refuses candidate and employer accounts. Sign out and sign back in after the claim is granted so Firebase issues a fresh ID token.
5. Publish the updated repository `firestore.rules` in Firebase Console → Firestore Database → Rules. Employer registration now creates a `pending` profile; clients cannot mark it approved or grant themselves posting credits.

The admin password and Firebase service account private key must never be placed in `admin-web/` or committed to Git.

## Local preview

1. Copy `admin-web/.env.example` to `admin-web/.env.local` and enter the Firebase **web app** values. Set `VITE_API_BASE_URL=http://localhost:5000` for a local backend or the deployed backend URL for a remote test.
2. Set `CLIENT_URL_ADMIN=http://localhost:5173` in the backend environment. Start the backend with `npm run dev` from `backend/`.
3. Run `npm install` and `npm run dev` from `admin-web/`, then open the Vite URL. There is no admin sign-up page.

`GET /api/admin/me` requires a Firebase ID token with a verified email and `admin: true` claim. The backend checks token revocation and returns only the admin UID, email and role. Missing tokens return 401; ordinary signed-in users return 403.

## Vercel deployment

Deploy `admin-web/` as a **separate Vercel project** with root directory `admin-web`, build command `npm run build`, and output directory `dist`. Set all five `VITE_` variables in that project's environment; `VITE_API_BASE_URL` should point to the deployed backend. Set `CLIENT_URL_ADMIN` in the backend project's environment to the admin website's exact HTTPS origin (no trailing slash), then redeploy the backend. Add the admin website hostname to Firebase Authentication's authorized domains.

The web app will show a setup message until the required configuration is present. No admin account, Firebase web app, or production deployment is created automatically by this repository.

## Employer review during this first release

The dashboard is intentionally empty. New employer registrations remain `pending` until a verified admin reviews them. The backend already exposes protected employer review endpoints documented in `EMPLOYER_SETUP.md`; an approval screen can be added in a later release. Until then, a trusted operator must use those backend endpoints for review. Employer actions require the review record written by that endpoint, so any older `approved` profile without `reviewedBy` and `reviewedAt` must be reviewed again. The free starter credit can be activated only once after approval.
