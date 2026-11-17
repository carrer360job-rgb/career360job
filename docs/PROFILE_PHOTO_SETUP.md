# Profile photos and company logos

Candidates can add, replace, and remove a JPG, PNG, or WebP profile photo up to 3 MB from the camera icon on their profile. The Flutter app uploads to the public Supabase Storage `profile-photos` bucket under the signed-in user's ID, then stores the public URL in `public.candidate_profiles.profile_photo_url`.

Employers can add, replace, and remove a company logo from the camera icon on the Company tab. The same size and file type limits apply. The logo is stored under the employer's user ID in `profile-photos`, with its URL saved in `public.employers.logo_url`.

Apply [`backend/sql/candidate_profile_photo_storage.sql`](../backend/sql/candidate_profile_photo_storage.sql) to grant each authenticated account upload, replace, and delete access only within its own folder. The bucket must remain public for avatar and logo URLs to display. Anyone with a photo URL can view it; do not upload sensitive documents as a profile photo or logo.

The app reports success only after Storage accepts the image and the profile URL is saved. Replacing an image adds a version to the displayed URL to refresh caches. Removing an image deletes the stored object and clears the profile URL. Existing attempts made before this fix must be uploaded again: those attempts returned a URL despite the upload failing.
