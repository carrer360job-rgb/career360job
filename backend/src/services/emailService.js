import nodemailer from 'nodemailer';

let transporter = null;

// Initialize mail transporter
const initTransporter = () => {
  if (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS) {
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: parseInt(process.env.SMTP_PORT || '587', 10),
      secure: process.env.SMTP_SECURE === 'true',
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
    console.log('[EmailService] SMTP transporter configured with host:', process.env.SMTP_HOST);
  } else if (process.env.GMAIL_USER && process.env.GMAIL_APP_PASSWORD) {
    transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.GMAIL_USER,
        pass: process.env.GMAIL_APP_PASSWORD,
      },
    });
    console.log('[EmailService] Gmail transporter configured for:', process.env.GMAIL_USER);
  } else {
    console.warn('[EmailService] No SMTP credentials provided. OTPs will be logged to console in development mode.');
  }
};

initTransporter();

/**
 * Send OTP Verification Email
 */
export async function sendOtpEmail({ to, otp, type = 'verification' }) {
  const subjectMap = {
    verification: 'Career360 - Verify Your Email Address',
    signup: 'Career360 - Activate Your Candidate Account',
    password_reset: 'Career360 - Password Reset Code',
  };

  const subject = subjectMap[type] || 'Career360 - Verification Code';

  const htmlContent = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F8FAFC; margin: 0; padding: 24px; }
        .card { max-width: 500px; margin: 0 auto; background: #FFFFFF; border: 1px solid #E2E8F0; border-radius: 12px; padding: 32px; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05); }
        .logo { font-size: 24px; font-weight: 800; color: #155EEF; letter-spacing: -0.5px; margin-bottom: 8px; }
        .tagline { font-size: 13px; color: #64748B; margin-bottom: 24px; }
        .title { font-size: 18px; font-weight: 600; color: #0B1F3A; margin-bottom: 12px; }
        .desc { font-size: 14px; color: #475467; line-height: 1.6; margin-bottom: 24px; }
        .otp-box { background: #EFF4FF; border: 2px dashed #B2CCFF; border-radius: 8px; padding: 18px; text-align: center; margin-bottom: 24px; }
        .otp-code { font-size: 32px; font-weight: 700; color: #155EEF; letter-spacing: 8px; font-family: monospace; }
        .expiry { font-size: 12px; color: #64748B; margin-top: 6px; }
        .footer { font-size: 12px; color: #94A3B8; text-align: center; margin-top: 32px; border-top: 1px solid #F1F5F9; padding-top: 16px; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="logo">Career360</div>
        <div class="tagline">Job Portal Platform</div>
        <div class="title">Your Verification Code</div>
        <div class="desc">Please use the 6-digit code below to complete your ${type === 'password_reset' ? 'password reset' : 'account verification'}.</div>
        <div class="otp-box">
          <div class="otp-code">${otp}</div>
          <div class="expiry">Expires in 10 minutes</div>
        </div>
        <div class="desc">If you did not request this code, you can safely ignore this email.</div>
        <div class="footer">
          &copy; ${new Date().getFullYear()} Career360. All rights reserved.
        </div>
      </div>
    </body>
    </html>
  `;

  if (transporter) {
    try {
      const from = process.env.EMAIL_FROM || '"Career360" <noreply@career360.com>';
      await transporter.sendMail({
        from,
        to,
        subject,
        html: htmlContent,
      });
      console.log(`[EmailService] OTP successfully emailed to ${to}`);
      return { success: true, delivered: true };
    } catch (err) {
      console.error(`[EmailService] Error delivering email to ${to}:`, err.message);
      // Fallback: log for development
      console.log(`[DEV OTP FALLBACK] Code for ${to}: [${otp}]`);
      return { success: true, delivered: false, error: err.message };
    }
  } else {
    console.log(`[DEV MODE - NO SMTP] ---------------------------------`);
    console.log(`[DEV MODE] OTP Code for ${to} (${type}): [ ${otp} ]`);
    console.log(`[DEV MODE] ---------------------------------`);
    return { success: true, delivered: false, devMode: true };
  }
}
