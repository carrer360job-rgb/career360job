export type AdminIdentity = {
  uid: string;
  email: string;
  role: 'admin';
};

export class ApiError extends Error {
  constructor(public readonly status: number) {
    super(status === 401 ? 'Your session has expired.' :
      status === 403 ? 'This account does not have admin access.' :
      'The admin service is unavailable. Try again.');
  }
}

export async function getAdminIdentity(token: string): Promise<AdminIdentity> {
  const baseUrl = import.meta.env.VITE_API_BASE_URL.trim().replace(/\/$/, '');
  let response: Response;
  try {
    response = await fetch(`${baseUrl}/api/admin/me`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: 'no-store',
    });
  } catch {
    throw new ApiError(0);
  }
  if (!response.ok) throw new ApiError(response.status);
  const identity: unknown = await response.json();
  if (!identity || typeof identity !== 'object' ||
      !('role' in identity) || identity.role !== 'admin' ||
      !('uid' in identity) || typeof identity.uid !== 'string' ||
      !('email' in identity) || typeof identity.email !== 'string') {
    throw new ApiError(0);
  }
  return identity as AdminIdentity;
}
