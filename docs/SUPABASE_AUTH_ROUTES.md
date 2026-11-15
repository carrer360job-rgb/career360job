# Supabase Auth and API authorization

The Android app and admin website sign in through Supabase Auth. The Express API accepts Supabase access tokens in `Authorization: Bearer <token>` and validates them with Supabase Auth on each protected request. Firebase ID tokens are not accepted by these routes.

`GET /api/auth/me` returns the current Supabase user ID, email, role, and email verification status. `GET /api/employer/me` requires an employer profile and returns its approval and credit state. `GET /api/admin/me` additionally requires a confirmed email and `app_metadata.role = admin`. A client cannot set `app_metadata` through signup or `user_metadata` updates. Suspended and blocked profile rows are denied.

The project migrations `protect_supabase_auth_and_routes` and `scope_employer_job_policy_to_authenticated` restrict Data API grants and RLS. Anonymous clients can read published jobs and active plans. Signed-in users can edit their own candidate and employer details. Client requests cannot approve employers, set credits, change account status, or delete tables. Job publishing, applicant decisions, employer approval, payments, and broader admin operations still use legacy Firestore handlers and need a separate data migration before they work solely on Supabase.

For email-code signup, enable **Confirm email** in Supabase Auth and put `{{ .Token }}` in the **Confirm sign up** email template. See [EMAIL_OTP_SETUP.md](EMAIL_OTP_SETUP.md). The Supabase connection used here does not expose Auth configuration or email-template update tools, so those dashboard settings require an account administrator.

Set `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` only in the backend environment. Set `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, and `VITE_API_BASE_URL` in the admin website. Never place the service-role key in a browser or Android build.
