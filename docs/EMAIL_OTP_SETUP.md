# Email OTP signup setup with Resend SMTP

The Android create-account flow uses Supabase Auth signup, then verifies the six-digit email OTP code before the user continues to candidate personal details or employer company details. Google OAuth remains a separate sign-in flow and bypasses OTP verification because Google automatically verifies user identity.

---

## 1. Resend Sending Domain Configuration

1. Log into your [Resend Dashboard](https://resend.com/domains).
2. For testing, Resend provides `onboarding@resend.dev` which allows delivery to your account owner's email address or `delivered@resend.dev`.
3. For live/production delivery to any arbitrary candidate or employer email:
   - Click **Add Domain** (e.g. `career360.in` or `career360job.com`).
   - Add the generated `DKIM`, `SPF`, and `MX` DNS records to your domain provider (e.g., Cloudflare, GoDaddy, Namecheap).
   - Once verified, you can send from any address such as `auth@yourdomain.com` or `noreply@yourdomain.com`.

---

## 2. Supabase Custom SMTP Configuration

In the Supabase Dashboard for your project:

1. Navigate to **Project Settings** (gear icon) $\rightarrow$ **Authentication**.
2. Scroll to the **SMTP Settings** section.
3. Toggle **Enable Custom SMTP** to **ON**.
4. Fill in the following credentials:
   - **Sender email:** `onboarding@resend.dev` (or your verified domain address, e.g. `auth@career360.in`)
   - **Sender name:** `Career360`
   - **Host:** `smtp.resend.com`
   - **Port:** `587` (or `465` with SSL)
   - **User:** `resend`
   - **Password:** `<YOUR_RESEND_API_KEY>` *(Enter your API key securely here in Supabase settings — never commit it to source code)*
5. Click **Save Changes**.

---

## 3. Email Template & Confirmation Settings

1. Open **Authentication $\rightarrow$ Sign In / Providers $\rightarrow$ Email** and toggle **Confirm email** to **ON**.
   > *Note:* With automatic confirmation enabled, Supabase creates a session immediately and sends no signup confirmation email. The app rejects signup if confirmation is turned off.
2. Open **Authentication $\rightarrow$ Email Templates $\rightarrow$ Confirm sign up**.
   - Subject: `Your Career360 verification code`
   - Body: Ensure `{{ .Token }}` is present in the message body so the recipient receives the six-digit numerical code:
     ```html
     <h2>Confirm your Career360 account</h2>
     <p>Your 6-digit verification code is:</p>
     <p style="font-size: 26px; font-weight: bold; letter-spacing: 6px; color: #155EEF;">{{ .Token }}</p>
     <p>Enter this code in the Career360 app to complete your registration. This code will expire shortly.</p>
     ```
3. Open **Authentication $\rightarrow$ Rate Limits**:
   - Set **Email sent per hour** appropriately (e.g. `30` or `100` per hour, depending on your Resend plan allowance).

---

## 4. End-to-End Flow Verification

1. **Candidate Signup:**
   - On the Candidate login screen, tap "Sign up".
   - Enter full name, email, and password, then tap "Create Account & Send OTP".
   - App calls Supabase Auth signup; Supabase sends the 6-digit OTP code through Resend SMTP.
   - The app transitions to the "Check your inbox" screen with a 6-digit input, countdown timer (60s), and "Change email" option.
   - Enter the 6-digit code. Supabase verifies the OTP, provisions the role in `profiles`, and advances the user into the **Candidate Onboarding Wizard** (personal details, skills, location).

2. **Employer Signup:**
   - Open Employer Login $\rightarrow$ Sign Up.
   - Enter company contact name, email, and password, then tap "Create Account & Send OTP".
   - Enter the 6-digit code. On successful verification, the app advances the user directly to the **Employer Registration Screen** (company name, district, contact number).

3. **Google Sign-In:**
   - Tap "Continue with Google".
   - OAuth completes and authenticates the user directly into onboarding without an unnecessary email OTP.

4. **Error Handling:**
   - **Wrong code:** Shows clear error message without clearing email state.
   - **Expired code:** Notifies user that the code has expired and suggests requesting a new code.
   - **Rate limit:** Resend button enforces a 60-second cooldown timer before allowing another request.
