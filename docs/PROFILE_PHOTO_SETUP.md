# Candidate profile photo

Candidates can add, replace, and remove a JPG, PNG, or WebP profile photo up to 3 MB from the camera icon on their profile. The Flutter app uploads to the public Supabase Storage `profile-photos` bucket under the signed-in user's ID, then stores the public URL in `public.candidate_profiles.profile_photo_url`.

Apply [`backend/sql/candidate_profile_photo_storage.sql`](../backend/sql/candidate_profile_photo_storage.sql) to grant each authenticated candidate upload, replace, and delete access only within their own folder. The bucket must remain public for avatar URLs to display. Anyone with a photo URL can view it; do not upload sensitive documents as a profile photo.

The app reports success only after Storage accepts the image and the profile URL is saved. Replacing an image adds a version to the displayed URL to refresh caches. Removing an image deletes the stored object and clears the profile URL. Existing attempts made before this fix must be uploaded again: those attempts returned a URL despite the upload failing.
