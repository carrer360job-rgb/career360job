export function requireAdmin(req, res, next) {
  if (req.user?.email_verified !== true || req.user?.admin !== true) {
    return res.status(403).json({
      error: { message: 'Admin access required.' },
    });
  }
  next();
}
