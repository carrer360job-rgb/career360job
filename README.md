# Career360

Career360 is an Android job portal built with Flutter, Firebase Authentication, Cloud Firestore, and an Express backend. Candidate profile photos use Cloudinary. The employer flow uses the backend for paid plans, job publishing, applicant decisions, and controlled candidate contact access.

## Run the Android app

Requirements: Flutter SDK, Android SDK, and a configured Android device or emulator.

```powershell
cd frontend
flutter pub get
flutter run -d YOUR_DEVICE_ID
```

### Candidate sample jobs for client preview

Debug builds show 10 fictional jobs in a separate **Sample jobs** section. They are stored in the app, not in Firestore. Preview Apply never creates an application, and preview bookmarks exist only until the app restarts. The employer and admin views use only live Firestore jobs.

To hide the samples while developing:

```powershell
flutter run --dart-define=SHOW_SAMPLE_JOBS=false
```

Release builds hide them by default. The setting is defined in `frontend/lib/core/config/sample_jobs_config.dart`. Preview and approve the app through USB debugging before creating a distributable APK.

The Android Firebase configuration is `frontend/android/app/google-services.json`. It must belong to Firebase project `career360-7f60f` and match Android application ID `com.career360.candidate`.

## Backend

The backend handles candidate profile photo uploads, employer hiring actions, and Razorpay payment verification. Configure `backend/.env` from `backend/.env.example`, then run:

```powershell
cd backend
npm install
npm run dev
```

The custom backend OTP flow has been removed from the API. Email/password sign-up and verification use Firebase Authentication.
Candidate Google sign-in uses Firebase Authentication's single browser flow on Android; it does not open a separate native account picker first.

For candidate profile photo uploads, follow [`docs/PROFILE_PHOTO_SETUP.md`](docs/PROFILE_PHOTO_SETUP.md). Run Flutter with `--dart-define=API_BASE_URL=https://YOUR_BACKEND` when testing another backend.

The employer registration, company approval, posting plan, Razorpay webhook, and USB preview steps are in [`docs/EMPLOYER_SETUP.md`](docs/EMPLOYER_SETUP.md).

## Admin website

The separate React admin website is in `admin-web/`. Its first release provides email/password sign-in and a protected empty dashboard. Configure its Firebase web app and backend URL as described in [`docs/ADMIN_WEB_SETUP.md`](docs/ADMIN_WEB_SETUP.md), then run `npm install` and `npm run dev` from `admin-web/`.

## Security configuration

- Firestore rules are in [`firestore.rules`](firestore.rules) and are selected by [`firebase.json`](firebase.json).
- Review and validate rules with the Firebase Emulator Suite before deploying them.
- Android release builds still need a protected release signing configuration; the current Gradle release configuration uses the debug key.
