# Hosted Supabase password recovery email

The app uses Supabase Auth recovery codes. In the hosted Supabase project,
open **Authentication → Email Templates → Reset password** and set:

- Subject: `Your Career360 password reset code`
- Body: the contents of [`recovery.html`](recovery.html)

Save the template in the Supabase dashboard. The recovery body must contain
`{{ .Token }}` and must not contain `{{ .ConfirmationURL }}`. The checked-in
file documents the required hosted configuration; changing it in Git alone
does not update Supabase's hosted email template.
