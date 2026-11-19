class JobModel {
  final String id;
  final String title;
  final String companyName;
  final String locationCity;
  final String salaryText;
  final String category;
  final String workMode; // On-Site, Remote, Hybrid
  final int vacanciesCount;
  final String description;
  final bool isVerified;
  final DateTime postedAt;
  final String? employerUid;
  final String? phone;
  final String? email;
  final String? whatsappNumber;
  final String? contactName;
  final String status;
  final DateTime? expiresAt;
  final bool isFeatured;
  final bool isStatewide;
  final String planTier;
  final String planName;

  bool get isOpen => status == 'active' &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  /// Local preview content only. Firestore documents are always real jobs.
  final bool isDemo;
  final List<String> requirements;
  final List<String> responsibilities;

  JobModel({
    required this.id,
    required this.title,
    required this.companyName,
    required this.locationCity,
    required this.salaryText,
    required this.category,
    required this.workMode,
    required this.vacanciesCount,
    required this.description,
    this.isVerified = true,
    required this.postedAt,
    this.employerUid,
    this.phone,
    this.email,
    this.whatsappNumber,
    this.contactName,
    this.status = 'active',
    this.expiresAt,
    this.isFeatured = false,
    this.isStatewide = false,
    this.planTier = '',
    this.planName = '',
    this.isDemo = false,
    this.requirements = const [],
    this.responsibilities = const [],
  });

  factory JobModel.fromMap(Map<String, dynamic> data, [String? id]) {
    final docId = id ?? (data['id']?.toString() ?? '');
    DateTime posted = DateTime.now();
    final rawPosted = data['postedAt'] ?? data['posted_at'] ?? data['createdAt'] ?? data['created_at'];
    if (rawPosted is DateTime) {
      posted = rawPosted;
    } else if (rawPosted is String) {
      posted = DateTime.tryParse(rawPosted) ?? DateTime.now();
    }

    DateTime? expires;
    final rawExpires = data['expiresAt'] ?? data['expires_at'] ?? data['deadline'];
    if (rawExpires is DateTime) {
      expires = rawExpires;
    } else if (rawExpires is String) {
      expires = DateTime.tryParse(rawExpires);
    }

    final locationStr = data['locationCity'] ?? data['location_city'] ?? data['district'] ?? 'Tamil Nadu / Remote';
    final minimum = data['min_salary'] ?? data['minSalary'];
    final maximum = data['max_salary'] ?? data['maxSalary'];
    final salary = minimum == null ? 'Salary not specified' :
        maximum == null || maximum == minimum ? '₹$minimum' : '₹$minimum - ₹$maximum';
    final rawStatus = (data['status']?.toString() ?? 'active').toLowerCase();
    final isStatewideJob = data['isStatewide'] == true ||
        data['is_statewide'] == true ||
        data['reach'] == 'statewide' ||
        locationStr.toString().toLowerCase().contains('all tamil nadu');

    return JobModel(
      id: docId,
      title: data['title'] ?? 'Untitled Opportunity',
      companyName: data['companyName'] ?? data['company_name'] ??
          (data['employers'] is Map ? data['employers']['company_name'] : null) ??
          'Career360 Partner',
      locationCity: locationStr,
      salaryText: data['salaryText'] ?? data['salary_text'] ?? salary,
      category: data['category'] ?? 'IT & Software',
      workMode: data['workMode'] ?? data['work_mode'] ?? data['job_type'] ?? 'On-site',
      vacanciesCount: (data['vacanciesCount'] is int)
          ? data['vacanciesCount']
          : (data['vacancies_count'] is int)
              ? data['vacancies_count']
          : int.tryParse(data['vacanciesCount']?.toString() ?? data['vacancies_count']?.toString() ?? data['vacancies']?.toString() ?? '1') ?? 1,
      description: data['description'] ?? 'Verified Career360 job opening.',
      isVerified: data['isVerified'] ?? data['is_verified'] ??
          (data['employers'] is Map ? data['employers']['is_verified'] : null) ?? false,
      postedAt: posted,
      employerUid: data['employerUid'] ?? data['employer_id'] ?? data['companyId'] ?? data['company_id'],
      phone: (data['phone'] ?? data['contact_phone']) as String?,
      email: (data['email'] ?? data['contact_email']) as String?,
      whatsappNumber: (data['whatsappNumber'] is String ? data['whatsappNumber'] as String : null) ??
          (data['whatsapp_number'] is String ? data['whatsapp_number'] as String : null) ??
          (data['phone'] is String ? data['phone'] as String : null),
      contactName: (data['contactName'] is String ? data['contactName'] as String : null) ??
          (data['contact_name'] is String ? data['contact_name'] as String : null),
      status: rawStatus == 'published' ? 'active' : rawStatus,
      expiresAt: expires,
      isFeatured: data['isFeatured'] == true || data['is_featured'] == true || data['planTier'] == 'featured' || data['planTier'] == 'elite',
      isStatewide: isStatewideJob,
      planTier: data['planTier'] is String ? data['planTier'] as String : (data['plan_tier'] is String ? data['plan_tier'] as String : ''),
      planName: data['planName'] is String ? data['planName'] as String : (data['plan_name'] is String ? data['plan_name'] as String : ''),
      requirements: (data['requirements'] as List<dynamic>?)?.whereType<String>().toList() ??
          (data['skills'] as List<dynamic>?)?.whereType<String>().toList() ??
          const [],
      responsibilities: (data['responsibilities'] as List<dynamic>?)?.whereType<String>().toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    if (isDemo) {
      throw StateError('Sample jobs cannot be written to database.');
    }
    return {
      'title': title,
      'district': locationCity,
      'salaryText': salaryText,
      'category': category,
      'workMode': workMode,
      'vacanciesCount': vacanciesCount,
      'description': description,
      'contactName': contactName,
      'phone': phone,
      'email': email,
      'whatsappNumber': whatsappNumber,
      'isStatewide': isStatewide,
    };
  }
}
