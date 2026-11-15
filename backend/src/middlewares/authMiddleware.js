import { supabaseAdmin } from '../config/supabase.js';

export function mapSupabaseIdentity(user, profile) {
  const isAdmin = user.app_metadata?.role?.toString().toUpperCase() === 'ADMIN';
  return {
    uid: user.id,
    email: user.email,
    email_verified: Boolean(user.email_confirmed_at),
    admin: isAdmin,
    role: isAdmin ? 'ADMIN' : (profile?.role || 'CANDIDATE'),
  };
}

export async function verifySupabaseToken(req, res, next) {
  const authorization = req.headers.authorization;
  if (!authorization?.startsWith('Bearer ')) {
    return res.status(401).json({ error: { message: 'A bearer token is required.' } });
  }

  const token = authorization.slice(7).trim();
  if (!token) {
    return res.status(401).json({ error: { message: 'A bearer token is required.' } });
  }

  try {
    const { data, error } = await supabaseAdmin.auth.getUser(token);
    if (error || !data?.user) {
      return res.status(401).json({ error: { message: 'Invalid or expired session.' } });
    }

    const user = data.user;
    const { data: profile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('role,status')
      .eq('id', user.id)
      .maybeSingle();
    if (profileError) throw profileError;
    if (profile?.status === 'SUSPENDED' || profile?.status === 'BLOCKED') {
      return res.status(403).json({ error: { message: 'This account is unavailable.' } });
    }

    req.user = mapSupabaseIdentity(user, profile);
    return next();
  } catch (error) {
    console.error('[Supabase Auth]', error);
    return res.status(503).json({ error: { message: 'Authentication is temporarily unavailable.' } });
  }
}

// Preserve route imports while all protected routes use Supabase Auth.
export const verifyFirebaseToken = verifySupabaseToken;
export const verifySensitiveToken = verifySupabaseToken;
export const verifyAdminToken = verifySupabaseToken;
