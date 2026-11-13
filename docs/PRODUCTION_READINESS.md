# Career360 Production Readiness Plan

This plan reflects the repository as it exists today and targets Android only. The Flutter app currently handles sign-in and product data through Firebase Auth and Cloud Firestore. Android's Firebase config is present for project `career360-7f60f` and matches application ID `com.career360.candidate`. The Express API and Prisma schema are a partial second backend; the documented recruiter, billing, and admin services are not implemented yet.

## Recommended architecture decision

For the first production release, keep Firebase Auth and Firestore as the source of truth. They already power the candidate flows and job/applicant screens. Treat the Express/Postgres backend as non-production until its authentication, authorization, and data flows are deliberately brought into the product. Avoid writing the same job, user, or application data to both systems.

Revisit Postgres when there is a concrete need for relational reporting, billing, or recruiter workflows that Firestore does not serve well. At that point, migrate with an explicit ownership boundary and backfill plan rather than running two writable sources of truth.

## Release gates

### P0 — Security and data integrity

- [ ] Add and review Firestore security rules. Require Firebase Authentication; restrict user and candidate documents to their owner; define public job reads and authenticated employer writes explicitly; prevent clients from setting privileged roles, verification state, or billing fields.
- [ ] Add Firebase Emulator tests for every rule path before deploying rules.
- [ ] Remove or disable the backend OTP endpoints until they use a production-safe design. The current code derives OTPs predictably from a time slot, has a hardcoded fallback secret, returns an OTP-verification token that permits offline guessing, and stores resend limits in per-process memory. Prefer Firebase Auth's supported verification flows or a shared, persistent challenge store with strict attempt and resend limits.
- [ ] Confirm Firebase Auth providers and Android app settings are configured in the `career360-7f60f` project. Do not silently continue into an apparently usable app when Firebase initialization fails.
- [ ] Remove privileged service credentials from client builds and repository history; rotate any credential that may have been committed. The Android Firebase config is client configuration, but must still be constrained by Firebase rules and provider settings.
- [ ] Define account deletion and data export/deletion behavior for Auth and Firestore records.

### P1 — Core candidate experience

- [ ] Define Firestore document shapes and required fields for jobs, users, candidates, and applications; add validation at trusted write boundaries.
- [ ] Make apply idempotent and prevent duplicate applications with rules and/or a trusted backend operation. Verify that candidates cannot edit employer-owned job content or other users' applications.
- [ ] Add loading, empty, offline, permission-denied, and retry states to primary job and profile flows.
- [ ] Audit onboarding writes and ensure failures are shown to the user instead of swallowed; confirm profile completion survives sign-out and reinstall.
- [ ] Review location permission prompts and provide a useful manual location path when permission is declined.

### P2 — Operations and abuse controls

- [ ] Add structured, privacy-conscious error reporting and crash reporting; never log passwords, OTPs, tokens, or full personal profiles.
- [ ] Set Firebase billing alerts, quotas, backups/export policy, and production/staging project separation.
- [ ] Add abuse controls for account creation, job posting, application spam, and any public callable/API endpoints.
- [ ] Publish privacy policy, support contact, retention periods, and verified-employer review process that match actual behavior.

### P3 — Release quality

- [ ] Replace stale setup and feature claims in README with commands and functionality that exist in this repository.
- [ ] Add automated checks for Flutter analysis/build and backend lint/build plus Firebase Emulator rule tests.
- [ ] Verify Android release builds and auth behavior on real devices; check accessibility, responsive layouts, and slow/offline network behavior.
- [ ] Replace the debug signing config in `frontend/android/app/build.gradle.kts` with protected release signing; configure versioning, privacy disclosures, store assets, and a rollback/release checklist.

## First implementation milestone

1. Inspect the Android Firebase project configuration and current Firestore data shapes/rules.
2. Add least-privilege Firestore rules plus emulator coverage.
3. Remove the unused insecure backend OTP path or replace it with a supported Firebase flow.
4. Align README/setup instructions with the actual Firebase-first architecture.

Do not enable production traffic until the P0 gate is complete and reviewed against the deployed Firebase project.
