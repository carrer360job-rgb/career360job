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
  });

  factory JobModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime posted = DateTime.now();
    if (data['postedAt'] is Timestamp) {
      posted = (data['postedAt'] as Timestamp).toDate();
    } else if (data['postedAt'] is String) {
      posted = DateTime.tryParse(data['postedAt']) ?? DateTime.now();
    }

    return JobModel(
      id: doc.id,
      title: data['title'] ?? 'Untitled Opportunity',
      companyName: data['companyName'] ?? 'Career360 Partner',
      locationCity: data['locationCity'] ?? 'Tamil Nadu / Remote',
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
    );
  }

  Map<String, dynamic> toMap() {
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
