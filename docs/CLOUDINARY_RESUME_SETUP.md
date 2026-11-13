# Candidate resume uploads with Cloudinary

The Android app uses Firebase Authentication and Firestore. Resume PDF bytes go to Cloudinary; the backend signs each upload and writes the candidate's resume metadata to Firestore. Firebase Storage and its paid-plan setup are not required for this feature.

## What you need to set up

1. Create a Cloudinary account. In its dashboard, copy the **cloud name**, **API key**, and **API secret**. No upload preset is needed: the backend creates a signed upload request. Keep the API secret on the backend only.
2. Give the backend Firebase Admin credentials. For local development, put a Firebase service-account JSON file in `backend/` named `firebase-service-account.json` (ignored by Git), or set `FIREBASE_SERVICE_ACCOUNT` to the entire JSON object as an environment variable. In Firebase Console, find this under **Project settings → Service accounts → Generate new private key**. Never put this file or value in the Android app.
3. Add these backend environment variables locally in `backend/.env`, and in your deployed backend's environment settings:

   ```text
   CLOUDINARY_CLOUD_NAME=your_cloud_name
   CLOUDINARY_API_KEY=your_api_key
   CLOUDINARY_API_SECRET=your_api_secret
   FIREBASE_SERVICE_ACCOUNT={"project_id":"...","client_email":"...","private_key":"..."}
   ```

   The service-account variable is optional when you use the local JSON file. On a deployed server, set it as a secret environment variable. Use the actual Firebase project that powers the Android app.
4. Publish the updated `firestore.rules` in **Firebase Console → Firestore Database → Rules**. These rules reserve `resumePublicId`, `resumeFileName`, and `resumeUpdatedAt` for backend writes. The backend Admin SDK bypasses client security rules. You do not need Firebase Storage rules for this flow.
5. Install and start the backend:

   ```powershell
   cd backend
   npm install
   npm run dev
   ```

   Deploy it to an HTTPS URL before testing on a physical Android device. Set the same backend environment variables on the deployment. Open `https://YOUR_BACKEND/api/health` to check that the API starts; this health route does not check the Cloudinary credentials.
6. Run the Android app with the backend URL:

   ```powershell
   cd frontend
   flutter pub get
   flutter run -d v2437 --dart-define=API_BASE_URL=https://YOUR_BACKEND
   ```

   Replace `v2437` with your device ID. Use the backend origin only, without `/api` at the end. For release builds, pass the same `--dart-define=API_BASE_URL=...` option to `flutter build apk` or `flutter build appbundle`.

## Check the complete flow

Sign in with a verified Firebase account. On the candidate profile, open **Resume**, choose a PDF under 10 MB, and wait for the success message. The filename should appear on the profile. Replace it once, then remove it. In Firestore, check `candidates/{uid}` for `resumePublicId`, `resumeFileName`, and `resumeUpdatedAt`. In Cloudinary Media Library, check the `candidate_resumes/{uid}` path. The upload is `authenticated`, so a public Cloudinary URL should not expose the PDF.

The backend allows 10 signed upload attempts per user per UTC day; failed attempts count too. It verifies the Cloudinary asset type and size before saving metadata. Production use still needs routine monitoring of Cloudinary usage and cleanup for signed uploads that never reach the finalize step.

Resumes previously uploaded to Firebase Storage are not moved automatically. Those users will need to upload their PDF again after this setup is live.
