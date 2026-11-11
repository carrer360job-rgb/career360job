import nodemailer from 'nodemailer';

let transporter = null;

// Initialize mail transporter
const initTransporter = () => {
  if (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS) {
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: parseInt(process.env.SMTP_PORT || '465', 10),
      secure: process.env.SMTP_SECURE === 'true' || process.env.SMTP_PORT === '465',
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
  } else if (!process.env.RESEND_API_KEY) {
    console.warn('[EmailService] No SMTP credentials configured. OTPs will be logged to console in development mode.');
  }
};

initTransporter();

/**
 * Send OTP Verification Email
 */
export async function sendOtpEmail({ to, otp, type = 'verification', name = null }) {
  const subjectMap = {
    verification: 'Career360 - Verify Your Email Address',
    signup: 'Career360 - Activate Your Candidate Account',
    password_reset: 'Career360 - Password Reset Code',
  };

  const actionTextMap = {
    verification: 'complete your email verification',
    signup: 'activate your Career360 candidate profile',
    password_reset: 'reset your account password securely',
  };

  const subject = subjectMap[type] || 'Career360 - Verification Code';
  const actionText = actionTextMap[type] || 'verify your account';
  const greeting = name ? `Hello ${name},` : 'Hello,';

  const htmlContent = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>${subject}</title>
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F8FAFC; margin: 0; padding: 32px 16px; color: #1E293B; }
        .card { max-width: 520px; margin: 0 auto; background: #FFFFFF; border: 1px solid #E2E8F0; border-radius: 16px; padding: 36px 32px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.05); }
        .header { display: flex; align-items: center; margin-bottom: 24px; padding-bottom: 20px; border-bottom: 1px solid #F1F5F9; }
        .logo { font-size: 22px; font-weight: 900; letter-spacing: 0.5px; color: #0A2351; }
        .logo span { color: #155EEF; }
        .pill { display: inline-block; background: #EFF4FF; color: #155EEF; font-size: 11px; font-weight: 700; padding: 4px 10px; border-radius: 20px; margin-bottom: 16px; letter-spacing: 0.5px; }
        .title { font-size: 20px; font-weight: 700; color: #0B1F3A; margin: 0 0 10px 0; }
        .greeting { font-size: 15px; font-weight: 600; color: #334155; margin-bottom: 8px; }
        .desc { font-size: 14px; color: #475467; line-height: 1.6; margin: 0 0 24px 0; }
        .otp-box { background: #F8FAFC; border: 2px dashed #93C5FD; border-radius: 12px; padding: 22px; text-align: center; margin-bottom: 24px; }
        .otp-code { font-size: 36px; font-weight: 800; color: #155EEF; letter-spacing: 10px; font-family: 'SF Mono', Consolas, Monaco, monospace; margin-left: 10px; }
        .expiry { font-size: 12px; color: #64748B; margin-top: 8px; font-weight: 500; }
        .security-note { background: #FEF3F2; border-left: 4px solid #F04438; padding: 12px 14px; border-radius: 6px; font-size: 12px; color: #B42318; line-height: 1.5; margin-bottom: 24px; }
        .footer { font-size: 12px; color: #94A3B8; text-align: center; border-top: 1px solid #F1F5F9; padding-top: 20px; line-height: 1.6; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="header">
          <div class="logo">CAREER<span>360</span></div>
        </div>
        <div class="pill">OFFICIAL VERIFICATION</div>
        <div class="greeting">${greeting}</div>
        <h1 class="title">Your One-Time Code</h1>
        <p class="desc">Please use the 6-digit verification code below to ${actionText}:</p>
        
        <div class="otp-box">
          <div class="otp-code">${otp}</div>
          <div class="expiry">⏱ Valid for 10 minutes (Single Use)</div>
        </div>

        <div class="security-note">
          <strong>Security Notice:</strong> Career360 will never ask for your password or code via phone call or messaging app. Never share this code with anyone.
        </div>

        <div class="footer">
          This is an automated security email from Career360.<br>
          &copy; ${new Date().getFullYear()} Career360 Platform. All rights reserved.
        </div>
      </div>
    </body>
    </html>
  `;

  // 1. Direct Resend REST API (Ultra-fast & serverless native)
  let lastError = null;
  if (process.env.RESEND_API_KEY) {
    try {
      const from = process.env.EMAIL_FROM || 'Career360 <onboarding@resend.dev>';
      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${process.env.RESEND_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from,
          to: [to],
          subject,
          html: htmlContent,
        }),
      });

      const data = await response.json();
      if (response.ok) {
        console.log(`[EmailService - Resend API] OTP successfully delivered to ${to} (ID: ${data.id})`);
        return { success: true, delivered: true, id: data.id };
      } else {
        lastError = data.message || 'Resend delivery rejected';
        console.error(`[EmailService - Resend API Error]:`, data);
      }
    } catch (apiErr) {
      lastError = apiErr.message;
      console.error(`[EmailService - Resend API Exception]:`, apiErr.message);
    }
  }

  // 2. SMTP Transporter Fallback
  if (transporter) {
    try {
      const from = process.env.EMAIL_FROM || '"Career360 Security" <onboarding@resend.dev>';
      const info = await transporter.sendMail({
        from,
        to,
        subject,
        html: htmlContent,
      });
      console.log(`[EmailService - SMTP] OTP successfully emailed to ${to}:`, info.messageId);
      return { success: true, delivered: true };
    } catch (err) {
      lastError = err.message;
      console.error(`[EmailService - SMTP Error] delivering to ${to}:`, err.message);
    }
  }

  // 3. If delivery failed in production
  if (process.env.NODE_ENV === 'production' || process.env.RESEND_API_KEY) {
    return {
      success: false,
      delivered: false,
      error: lastError || 'Email delivery failed. Please verify recipient address.',
    };
  }

  // 4. Local Development Fallback
  console.log(`[DEV MODE - NO SMTP] ---------------------------------`);
  console.log(`[DEV MODE] OTP Code for ${to} (${type}): [ ${otp} ]`);
  console.log(`[DEV MODE] ---------------------------------`);
  return { success: true, delivered: false, devMode: true };
}
