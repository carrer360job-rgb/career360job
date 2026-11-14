export type AdminIdentity = {
  uid: string;
  email: string;
  role: 'admin';
};

export class ApiError extends Error {
  constructor(public readonly status: number, message?: string) {
    super(message || (status === 401 ? 'Your session has expired.' :
      status === 403 ? 'This account does not have admin access.' :
      'The admin service is unavailable. Try again.'));
  }
}

const apiBaseUrl = import.meta.env.VITE_API_BASE_URL?.trim().replace(/\/$/, '') || '';

async function adminRequest<T>(token: string, path: string, method = 'GET', body?: unknown): Promise<T> {
  if (!apiBaseUrl) throw new ApiError(0, 'Configure the admin backend URL.');
  let response: Response;
  try {
    response = await fetch(`${apiBaseUrl}/api/admin${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        ...(body ? { 'Content-Type': 'application/json' } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
      cache: 'no-store',
    });
  } catch {
    throw new ApiError(0, 'Could not reach the admin backend. Check your connection.');
  }
  if (!response.ok) {
    const data = await response.json().catch(() => null);
    throw new ApiError(response.status, data?.error?.message);
  }
  return (await response.json()) as T;
}

export type PlanDraft = {
  name: string; tier: 'free' | 'standard' | 'featured' | 'elite'; badge: string;
  pricePaise: number; taxMode: 'inclusive' | 'exclusive'; taxRateBps: number;
  jobCredits: number; listingDays: number; creditValidityDays: number;
  profileUnlockLimit: number; reach: 'district' | 'statewide'; sortOrder: number;
  features: string[];
};
export type PublishedPlan = PlanDraft & {
  id: string; version: number; amountPaise: number; basePaise: number;
  taxPaise: number; totalPaise: number; priceDisplay: string; gstDisplay: string;
};
export type PlanEntry = { id: string; version: number; draft: PlanDraft | null; published: PublishedPlan | null };

export const listPlans = (token: string) => adminRequest<{ plans: PlanEntry[] }>(token, '/plans');
export const seedPlans = (token: string) => adminRequest<{ status: string }>(token, '/plans/seed', 'POST');
export const savePlan = (token: string, id: string, draft: PlanDraft) =>
  adminRequest<{ id: string; draft: PlanDraft }>(token, `/plans/${encodeURIComponent(id)}/draft`, 'PUT', draft);
export const publishPlan = (token: string, id: string) =>
  adminRequest<{ plan: PublishedPlan }>(token, `/plans/${encodeURIComponent(id)}/publish`, 'POST');
export const archivePlan = (token: string, id: string) =>
  adminRequest<{ status: string }>(token, `/plans/${encodeURIComponent(id)}/archive`, 'POST');

export type PlatformStats = {
  totalCandidates: number;
  totalEmployers: number;
  pendingEmployers: number;
  approvedEmployers: number;
  rejectedEmployers: number;
  totalJobs: number;
  activeJobs: number;
  closedJobs: number;
  totalApplications: number;
};

export type EmployerRecord = {
  uid: string;
  companyName: string;
  contactName: string;
  designation: string;
  email: string;
  phone: string;
  whatsappPhone: string;
  industry: string;
  companySize: string;
  state: string;
  district: string;
  address: string;
  postalCode: string;
  registrationNumber: string;
  status: 'pending' | 'approved' | 'rejected';
  postingCredits: number;
  activePlan: string;
  rejectionReason: string | null;
  reviewedBy: string | null;
  createdAt: string | null;
  reviewedAt: string | null;
};

export type JobRecord = {
  id: string;
  title: string;
  companyName: string;
  category: string;
  locationCity: string;
  workMode: string;
  salaryText: string;
  vacanciesCount: number;
  phone: string;
  whatsappNumber: string;
  email: string;
  contactName: string;
  status: 'active' | 'closed';
  isVerified: boolean;
  postedAt: string | null;
  expiresAt: string | null;
};

export const getStats = (token: string) => adminRequest<PlatformStats>(token, '/stats');

export const listEmployers = (token: string, status = 'all', search = '') =>
  adminRequest<{ employers: EmployerRecord[] }>(
    token,
    `/employers?status=${encodeURIComponent(status)}&search=${encodeURIComponent(search)}`
  );

export const reviewEmployer = (token: string, uid: string, decision: 'approved' | 'rejected', notes?: string) =>
  adminRequest<{ uid: string; status: string }>(
    token,
    `/employers/${encodeURIComponent(uid)}/review`,
    'POST',
    { decision, notes }
  );

export const listJobs = (token: string, status = 'all', search = '') =>
  adminRequest<{ jobs: JobRecord[] }>(
    token,
    `/jobs?status=${encodeURIComponent(status)}&search=${encodeURIComponent(search)}`
  );

export const closeJob = (token: string, jobId: string) =>
  adminRequest<{ status: string }>(token, `/jobs/${encodeURIComponent(jobId)}/close`, 'POST');

export async function getAdminIdentity(token: string): Promise<AdminIdentity> {
  const identity: unknown = await adminRequest(token, '/me');
  if (!identity || typeof identity !== 'object' ||
      !('role' in identity) || identity.role !== 'admin' ||
      !('uid' in identity) || typeof identity.uid !== 'string' ||
      !('email' in identity) || typeof identity.email !== 'string') {
    throw new ApiError(0, 'The admin backend returned an invalid response.');
  }
  return identity as AdminIdentity;
}
