# Career360 admin web setup

The admin website in `admin-web/` signs in with Supabase Auth. The Express API checks the Supabase access token and requires a confirmed email plus `app_metadata.role = admin` on `/api/admin/*`. A value in `user_metadata` or a matching email address does not grant admin access.

## Configure Auth and local preview

1. Use a dedicated Supabase Auth account for the administrator and confirm its email. The project already has one account with a trusted admin role. For another admin, set `app_metadata.role` to `admin` through a trusted Supabase Admin API process; never put the service-role key or an admin-role assignment in frontend code.
2. Copy `admin-web/.env.example` to `.env.local` and set `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, and `VITE_API_BASE_URL`. The publishable or legacy anon key is safe for the browser; the service-role key is not.
3. Set `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` in `backend/.env`. Set `CLIENT_URL_ADMIN=http://localhost:5173`. Run `npm run dev` in both `backend/` and `admin-web/`.
4. Sign in and verify that `GET /api/admin/me` returns the admin identity. Missing or invalid tokens return 401; signed-in non-admin users return 403.

## Vercel

Deploy `admin-web/` as a separate Vercel project with root directory `admin-web`, build command `npm run build`, and output directory `dist`. Set the same three `VITE_` variables in that project. Set the backend's `CLIENT_URL_ADMIN` to the website's exact HTTPS origin and deploy the backend changes separately.

## Current limitation

The admin login gate now uses Supabase Auth, but most dashboard business handlers still query Firebase Firestore. The admin dashboard is not fully migrated to Supabase data. Plan publishing, payment management, employer approval, and reports need a separate data and route migration before production use. See [SUPABASE_AUTH_ROUTES.md](SUPABASE_AUTH_ROUTES.md).
