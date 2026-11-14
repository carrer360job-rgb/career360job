import 'package:cloud_firestore/cloud_firestore.dart';

class EmployerProfile {
  final String uid;
  final String companyName;
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
  final String reviewedBy;
  final int postingCredits;
  final int listingDays;
  final DateTime? creditsExpireAt;
  final String activePlan;
  final String activePlanName;
  final String planTier;

  const EmployerProfile({
    required this.uid,
    required this.companyName,
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
    this.reviewedBy = '',
    required this.postingCredits,
    this.listingDays = 7,
    required this.creditsExpireAt,
    this.activePlan = 'free_starter',
    this.activePlanName = 'Free Starter Plan',
    this.planTier = 'free',
  });

  bool get isApproved => status != 'rejected';
  bool get hasActiveCredits =>
      postingCredits > 0 &&
      creditsExpireAt != null &&
      creditsExpireAt!.isAfter(DateTime.now());

  bool get isFreePlan => planTier == 'free' || activePlan == 'free_starter';
  bool get isStandardPlan =>
      planTier == 'standard' || activePlan == 'standard_15';
  bool get isFeaturedPlan =>
      planTier == 'featured' || activePlan == 'featured_30';
  bool get isElitePlan => planTier == 'elite' || activePlan == 'elite_all_tn';
  bool get canPostStatewide => isElitePlan;

  String get planBadgeText {
    if (isElitePlan) return 'ELITE ALL-TN 👑';
    if (isFeaturedPlan) return 'PREMIUM - 30 ⭐';
    if (isStandardPlan) return 'STARTER - 15';
    return 'FREE STARTER';
  }

  int get daysRemaining {
    if (creditsExpireAt == null) return 0;
    final diff = creditsExpireAt!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  factory EmployerProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    String value(String key) => data[key] is String ? data[key] as String : '';
    return EmployerProfile(
      uid: doc.id,
      companyName: value('companyName'),
      contactName: value('contactName'),
      designation: value('designation'),
      industry: value('industry'),
      companySize: value('companySize'),
      email: value('email'),
      phone: value('phone'),
      whatsappPhone: value('whatsappPhone'),
      whatsappSameAsPhone: data['whatsappSameAsPhone'] == true,
      website: value('website'),
      address: value('address'),
      city: value('city'),
      state: value('state'),
      district: value('district'),
      postalCode: value('postalCode'),
      description: value('description'),
      registrationNumber: value('registrationNumber'),
      status: value('status'),
      reviewedBy: value('reviewedBy'),
      postingCredits: data['postingCredits'] is int
          ? data['postingCredits'] as int
          : 0,
      listingDays: data['listingDays'] is int
          ? data['listingDays'] as int
          : (value('planTier') == 'elite' || value('planTier') == 'featured'
                ? 30
                : value('planTier') == 'standard'
                ? 15
                : 7),
      creditsExpireAt: data['creditsExpireAt'] is Timestamp
          ? (data['creditsExpireAt'] as Timestamp).toDate()
          : null,
      activePlan: value('activePlan').isNotEmpty
          ? value('activePlan')
          : 'free_starter',
      activePlanName: value('activePlanName').isNotEmpty
          ? value('activePlanName')
          : 'Free Starter Plan',
      planTier: value('planTier').isNotEmpty ? value('planTier') : 'free',
    );
  }
}
