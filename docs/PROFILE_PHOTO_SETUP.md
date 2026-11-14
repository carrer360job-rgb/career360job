# Candidate profile photo

Candidates can add, replace, and remove a profile photo from the camera icon on their profile avatar. Supported files are JPG, PNG, and WebP up to 3 MB. The Android app sends the image directly to Cloudinary using a signature from the authenticated backend; the backend records `profilePhotoPublicId`, `profilePhotoUrl`, and `profilePhotoUpdatedAt` in `candidates/{uid}`.

Profile photos use Cloudinary's public image delivery so they can be displayed as a candidate avatar. Anyone with a photo URL can view that image, and any verified app account with a known candidate UID can fetch that photo URL. Resume PDFs continue to use authenticated delivery. Do not upload a sensitive document as a profile photo.

Use the same backend `FIREBASE_SERVICE_ACCOUNT` (or separate Firebase Admin variables) and `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, and `CLOUDINARY_API_SECRET` described in [CLOUDINARY_RESUME_SETUP.md](CLOUDINARY_RESUME_SETUP.md). Add the variables to the deployed backend environment, redeploy the backend, and check `/api/resumes/ready`. Then publish the updated [Firestore rules](../firestore.rules); client apps cannot alter photo metadata directly.

An uploaded photo is shown on the candidate profile immediately after Firestore updates. The backend also publishes only the photo URL to `candidate_public_profiles/{uid}`. Verified employers viewing an applicant can see the current photo; changing or removing it updates that view. No phone number, resume, or other private candidate fields are copied into this public photo document.
