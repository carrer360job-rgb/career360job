# Career360

Career360 is currently being built as an Android job portal. The client is a Flutter app; Firebase Authentication and Cloud Firestore provide the active sign-in and app-data flows. An Express/Prisma backend is retained for planned trusted server operations, but most product features are not connected to it yet.

## Run the Android app

Requirements: Flutter SDK, Android SDK, and a configured Android device or emulator.

```powershell
cd frontend
flutter pub get
flutter run
```

The Android Firebase configuration is `frontend/android/app/google-services.json`. It must belong to Firebase project `career360-7f60f` and match Android application ID `com.career360.candidate`.

## Backend

The backend is an incomplete development component. Configure `backend/.env` from `backend/.env.example`, then run:

```powershell
cd backend
npm install
npm run dev
```

The custom backend OTP flow has been removed from the API. Email/password sign-up and verification use Firebase Authentication.

## Security configuration

- Firestore rules are in [`firestore.rules`](firestore.rules) and are selected by [`firebase.json`](firebase.json).
- Review and validate rules with the Firebase Emulator Suite before deploying them.
- Android release builds still need a protected release signing configuration; the current Gradle release configuration uses the debug key.
