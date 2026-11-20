class EmployerProfile {
  final String uid;
  final String companyName;
  final String logoUrl;
  final String contactName;
  final String designation;
  final String industry;
  final String companySize;
  final String email;
  final String phone;
  final String whatsappPhone;
  final bool whatsappSameAsPhone;
  final String website;
  final String address;
  final String city;
  final String state;
  final String district;
  final String postalCode;
  final String description;
  final String registrationNumber;
  final String status;
  final String reviewState;
  final String rejectionReason;
  final String reviewedBy;
  final bool isVerified;
  final int postingCredits;
  final int listingDays;
  final DateTime? creditsExpireAt;
  final String activePlan;
  final String activePlanName;
  final String planTier;
  final String planReach;

  const EmployerProfile({
    required this.uid,
    required this.companyName,
    this.logoUrl = '',
    required this.contactName,
    required this.designation,
    required this.industry,
    required this.companySize,
    required this.email,
    required this.phone,
    required this.whatsappPhone,
    required this.whatsappSameAsPhone,
    required this.website,
    required this.address,
    this.city = '',
    required this.state,
    required this.district,
    required this.postalCode,
    this.description = '',
    required this.registrationNumber,
    required this.status,
    this.reviewState = 'pending',
    this.rejectionReason = '',
    this.reviewedBy = '',
    this.isVerified = false,
    required this.postingCredits,
    this.listingDays = 7,
    required this.creditsExpireAt,
    this.activePlan = '',
    this.activePlanName = '',
    this.planTier = '',
    this.planReach = 'district',
  });

  bool get isApproved => reviewState == 'approved' && isVerified;
  bool get hasActiveCredits =>
      postingCredits > 0 &&
      const {'standard', 'featured', 'elite', 'monthly', 'quarterly', 'yearly'}.contains(planTier) &&
      creditsExpireAt != null &&
      creditsExpireAt!.isAfter(DateTime.now());
  bool get isStandardPlan =>
      planTier == 'standard' || activePlan == 'standard_15';
  bool get isFeaturedPlan =>
      planTier == 'featured' || activePlan == 'featured_30';
  bool get isElitePlan => planTier == 'elite' || activePlan == 'elite_all_tn';
  bool get canPostStatewide => planReach == 'statewide';

  String get planBadgeText {
    if (activePlan.isEmpty) return 'NO PLAN';
    if (planTier == 'monthly') return 'MONTHLY';
    if (planTier == 'quarterly') return 'QUARTERLY';
    if (planTier == 'yearly') return 'YEARLY';
    if (isElitePlan) return 'ELITE ALL-TN 👑';
    if (isFeaturedPlan) return 'PREMIUM - 30 ⭐';
    if (isStandardPlan) return 'STARTER - 15';
    return 'NO ACTIVE PLAN';
  }

  int get daysRemaining {
    if (creditsExpireAt == null) return 0;
    final diff = creditsExpireAt!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  factory EmployerProfile.fromMap(Map<String, dynamic> data, String uid) {
    String value(String key) => data[key] is String ? data[key] as String : '';
    return EmployerProfile(
      uid: uid,
      companyName: value('company_name').isNotEmpty
          ? value('company_name')
          : value('companyName'),
      logoUrl: value('logo_url').isNotEmpty
          ? value('logo_url')
          : value('logoUrl'),
      contactName: value('contact_name').isNotEmpty
          ? value('contact_name')
          : value('contactName'),
      designation: value('designation'),
      industry: value('industry'),
      companySize: value('company_size').isNotEmpty
          ? value('company_size')
          : value('companySize'),
      email: value('email'),
      phone: value('phone'),
      whatsappPhone: value('whatsapp_phone').isNotEmpty
          ? value('whatsapp_phone')
          : value('whatsappPhone'),
      whatsappSameAsPhone:
          data['whatsapp_same_as_phone'] == true ||
          data['whatsappSameAsPhone'] == true,
      website: value('website'),
      address: value('address'),
      city: value('city'),
      state: value('state').isNotEmpty ? value('state') : 'Tamil Nadu',
      district: value('district').isNotEmpty ? value('district') : 'Chennai',
      postalCode: value('postal_code').isNotEmpty
          ? value('postal_code')
          : value('postalCode'),
      description: value('description'),
      registrationNumber: value('registration_number').isNotEmpty
          ? value('registration_number')
          : value('registrationNumber'),
      status: value('status').isNotEmpty
          ? value('status')
          : (data['is_verified'] == true ? 'approved' : 'pending'),
      reviewState: value('review_state').isNotEmpty
          ? value('review_state')
          : (data['is_verified'] == true ? 'approved' : 'pending'),
      rejectionReason: value('rejection_reason'),
      reviewedBy: value('reviewed_by').isNotEmpty
          ? value('reviewed_by')
          : value('reviewedBy'),
      isVerified: data['is_verified'] == true,
      postingCredits: data['posting_credits'] is int
          ? data['posting_credits'] as int
          : (data['postingCredits'] is int ? data['postingCredits'] as int : 1),
      listingDays: data['listing_days'] is int
          ? data['listing_days'] as int
          : (data['listingDays'] is int ? data['listingDays'] as int : 30),
      creditsExpireAt: data['credits_expire_at'] is String
          ? DateTime.tryParse(data['credits_expire_at'] as String)
          : null,
      activePlan: value('active_plan').isNotEmpty
          ? value('active_plan')
          : value('activePlan'),
      activePlanName: value('active_plan_name').isNotEmpty
          ? value('active_plan_name')
          : value('activePlanName'),
      planTier: value('plan_tier').isNotEmpty
          ? value('plan_tier')
          : value('planTier'),
      planReach: value('plan_reach').isNotEmpty
          ? value('plan_reach')
          : (value('planReach').isNotEmpty ? value('planReach') : 'district'),
    );
  }
}
