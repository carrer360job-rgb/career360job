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
  name: string; tier: 'monthly' | 'quarterly' | 'yearly'; badge: string;
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
  status: 'pending' | 'approved' | 'rejected' | 'suspended';
  postingCredits: number;
  activePlan: string;
  rejectionReason: string | null;
  reviewedBy: string | null;
  createdAt: string | null;
  reviewedAt: string | null;
};

export type EmployerDetails = EmployerRecord & {
  logoUrl: string;
  whatsappSameAsPhone: boolean;
  website: string;
  description: string;
  city: string;
  accountStatus: string;
  emailVerified: boolean;
  lastSignInAt: string | null;
  activePlanName: string;
  planTier: string;
  planReach: string;
  listingDays: number;
  creditsExpireAt: string | null;
  updatedAt: string | null;
  subscriptions: Array<{ id: string; plan_name: string; total_posts: number; used_posts: number;
    starts_at: string; expires_at: string; status: string; order_id: string | null }>;
  orders: Array<{ id: string; plan_name: string; amount_paise: number; tax_paise: number;
    status: string; created_at: string; paid_at: string | null }>;
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

export const listEmployers = (token: string, status = 'all', search = '', cursor?: string) =>
  adminRequest<{ employers: EmployerRecord[]; nextCursor: string | null }>(
    token,
    `/employers?status=${encodeURIComponent(status)}&search=${encodeURIComponent(search)}${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`
  );

export const getEmployer = (token: string, uid: string) =>
  adminRequest<{ employer: EmployerDetails }>(token, `/employers/${encodeURIComponent(uid)}`);

export const adjustEmployerQuota = (token: string, uid: string, delta: number, reason: string) =>
  adminRequest<{ totalPosts: number; usedPosts: number }>(
    token, `/employers/${encodeURIComponent(uid)}/quota`, 'POST', { delta, reason });

export const reviewEmployer = (token: string, uid: string, decision: 'approved' | 'rejected', notes?: string) =>
  adminRequest<{ uid: string; status: string }>(
    token,
    `/employers/${encodeURIComponent(uid)}/review`,
    'POST',
    { decision, notes }
  );

export const listJobs = (token: string, status = 'all', search = '', cursor?: string) =>
  adminRequest<{ jobs: JobRecord[]; nextCursor: string | null }>(
    token,
    `/jobs?status=${encodeURIComponent(status)}&search=${encodeURIComponent(search)}${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`
  );

export const closeJob = (token: string, jobId: string) =>
  adminRequest<{ status: string }>(token, `/jobs/${encodeURIComponent(jobId)}/close`, 'POST');

export type JobSeekerRecord = { uid: string; email: string; displayName: string;
  disabled: boolean; emailVerified: boolean; createdAt: string | null; lastSignInAt: string | null };
export type JobSeekerDetails = Omit<JobSeekerRecord, 'displayName'> & {
  phone: string;
  profile: {
    fullName: string;
    district: string;
    personalDetails: Record<string, unknown>;
    education: Record<string, unknown>;
    preferredJobTitles: string[];
    experience: Record<string, unknown>;
    profilePhotoUrl: string | null;
    onboardingStep: number;
    onboardingCompletedAt: string | null;
    createdAt: string | null;
    updatedAt: string | null;
  };
};
export const listJobSeekers = (token: string, search = '', pageToken?: string) => adminRequest<{
  jobSeekers: JobSeekerRecord[]; nextPageToken: string | null;
}>(token, `/job-seekers?search=${encodeURIComponent(search)}${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''}`);
export const getJobSeeker = (token: string, uid: string) =>
  adminRequest<{ jobSeeker: JobSeekerDetails }>(token, `/job-seekers/${encodeURIComponent(uid)}`);
export const setUserDisabled = (token: string, uid: string, disabled: boolean, reason = '') =>
  adminRequest<{ uid: string; disabled: boolean; status: 'ACTIVE' | 'SUSPENDED' }>(token, `/users/${encodeURIComponent(uid)}/status`, 'POST', { disabled, reason });

export type PaymentRecord = { id: string; employerUid: string; planId: string; planName: string;
  amountPaise: number; basePaise: number; taxPaise: number; taxMode: string; taxRateBps: number;
  currency: string; status: string; paymentId: string | null; createdAt: string | null;
  paidAt: string | null; refundedAt: string | null; failedAt?: string | null; failureCode?: string | null;
  refundStatus?: string | null; refundReason?: string | null; refundRequestedAt?: string | null };
export const listPayments = (token: string, status = 'all', cursor?: string) =>
  adminRequest<{ available?: boolean; payments: PaymentRecord[]; nextCursor: string | null }>(token,
    `/payments?status=${encodeURIComponent(status)}${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`);
export const refundPayment = (token: string, orderId: string, reason: string) =>
  adminRequest<{ status: string; refundId: string | null }>(token, `/payments/${encodeURIComponent(orderId)}/refund`, 'POST', { reason });
export const reconcilePaymentRefund = (token: string, orderId: string) =>
  adminRequest<{ status: string }>(token, `/payments/${encodeURIComponent(orderId)}/reconcile`, 'POST');

export type JobReport = { id: string; jobId: string; jobTitle: string; companyName: string;
  candidateUid: string; reason: string; details: string; status: string; createdAt: string | null };
export type ReportSummary = { candidates: number; employers: number; jobs: number; applications: number; paidOrders: number };
export const getReports = (token: string, cursor?: string) => adminRequest<{
  available?: boolean; summary: ReportSummary | null; reports: JobReport[]; nextCursor: string | null;
}>(token, `/reports${cursor ? `?cursor=${encodeURIComponent(cursor)}` : ''}`);
export const resolveReport = (token: string, id: string, decision: 'dismissed' | 'job_closed', notes = '') =>
  adminRequest<{ status: string }>(token, `/reports/${encodeURIComponent(id)}/resolve`, 'POST', { decision, notes });

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
