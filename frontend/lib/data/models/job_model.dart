import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.planTier = 'free',
    this.planName = '',
    this.isDemo = false,
    this.requirements = const [],
    this.responsibilities = const [],
  });

  factory JobModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime posted = DateTime.now();
    if (data['postedAt'] is Timestamp) {
      posted = (data['postedAt'] as Timestamp).toDate();
    } else if (data['postedAt'] is String) {
      posted = DateTime.tryParse(data['postedAt']) ?? DateTime.now();
    }

    final locationStr = data['locationCity'] ?? 'Tamil Nadu / Remote';
    final isStatewideJob = data['isStatewide'] == true ||
        locationStr.toString().toLowerCase().contains('all tamil nadu');

    return JobModel(
      id: doc.id,
      title: data['title'] ?? 'Untitled Opportunity',
      companyName: data['companyName'] ?? 'Career360 Partner',
      locationCity: locationStr,
      salaryText: data['salaryText'] ?? '₹3 - 5 LPA',
      category: data['category'] ?? 'IT & Software',
      workMode: data['workMode'] ?? 'On-Site',
      vacanciesCount: (data['vacanciesCount'] is int)
          ? data['vacanciesCount']
          : int.tryParse(data['vacanciesCount']?.toString() ?? '1') ?? 1,
      description: data['description'] ?? 'Verified Career360 job opening.',
      isVerified: data['isVerified'] ?? true,
      postedAt: posted,
      employerUid: data['employerUid'],
      phone: data['phone'] is String ? data['phone'] as String : null,
      email: data['email'] is String ? data['email'] as String : null,
      whatsappNumber: (data['whatsappNumber'] is String ? data['whatsappNumber'] as String : null) ??
          (data['phone'] is String ? data['phone'] as String : null),
      contactName: data['contactName'] is String ? data['contactName'] as String : null,
      status: data['status'] is String ? data['status'] as String : 'active',
      expiresAt: data['expiresAt'] is Timestamp
          ? (data['expiresAt'] as Timestamp).toDate() : null,
      isFeatured: data['isFeatured'] == true || data['planTier'] == 'featured' || data['planTier'] == 'elite',
      isStatewide: isStatewideJob,
      planTier: data['planTier'] is String ? data['planTier'] as String : 'free',
      planName: data['planName'] is String ? data['planName'] as String : '',
      requirements:
          (data['requirements'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      responsibilities:
          (data['responsibilities'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    if (isDemo) {
      throw StateError('Sample jobs cannot be written to Firestore.');
    }
    return {
      'title': title,
      'companyName': companyName,
      'locationCity': locationCity,
      'salaryText': salaryText,
      'category': category,
      'workMode': workMode,
      'vacanciesCount': vacanciesCount,
      'description': description,
      'isVerified': isVerified,
      'postedAt': FieldValue.serverTimestamp(),
      'employerUid': employerUid,
    };
  }
}
