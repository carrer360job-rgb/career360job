import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/job_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton instance
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  CollectionReference get _jobsRef => _firestore.collection('jobs');
  CollectionReference get _applicationsRef => _firestore.collection('applications');
  CollectionReference get _usersRef => _firestore.collection('users');
  CollectionReference get _candidatesRef => _firestore.collection('candidates');

  /// 1. Real-Time Stream of Live Jobs from Cloud Firestore
  Stream<List<JobModel>> streamJobs({
    String? category,
    String? locationCity,
    String? searchQuery,
  }) {
    Query query = _jobsRef.orderBy('postedAt', descending: true);

    return query.snapshots().map((snapshot) {
      final jobs = snapshot.docs.map((doc) => JobModel.fromFirestore(doc)).toList();

      return jobs.where((job) {
        if (locationCity != null &&
            locationCity != 'All Locations' &&
            !job.locationCity.toLowerCase().contains(locationCity.toLowerCase())) {
          return false;
        }
        if (category != null &&
            category != 'All' &&
            category != 'All Categories' &&
            !job.category.toLowerCase().contains(category.toLowerCase())) {
          return false;
        }
        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          final q = searchQuery.toLowerCase();
          final matchesTitle = job.title.toLowerCase().contains(q);
          final matchesCompany = job.companyName.toLowerCase().contains(q);
          final matchesLoc = job.locationCity.toLowerCase().contains(q);
          final matchesCategory = job.category.toLowerCase().contains(q);
          return matchesTitle || matchesCompany || matchesLoc || matchesCategory;
        }
        return true;
      }).toList();
    });
  }

  /// 2. Post a Real Job to Cloud Firestore (Recruiter ATS)
  Future<String> createJobPost(JobModel job) async {
    try {
      final docRef = await _jobsRef.add(job.toMap());
      debugPrint('[FirestoreService] Job created successfully: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('[FirestoreService] Error creating job: $e');
      rethrow;
    }
  }

  /// 3. Seed Initial Live Jobs if Firestore Collection is Empty
  Future<void> seedInitialLiveJobsIfEmpty() async {
    try {
      final snapshot = await _jobsRef.limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        return; // Already has live jobs
      }

      debugPrint('[FirestoreService] Seeding initial live jobs to Firestore...');
      final initialJobs = [
        JobModel(
          id: '',
          title: 'Senior Flutter Developer (Mobile & Web)',
          titleTamil: 'மூத்த ஃப்ளட்டர் டெவலப்பர்',
          companyName: 'Zoho Corporation',
          locationCity: 'Chennai / Tenkasi',
          salaryText: '₹12 - 18 LPA',
          category: 'IT & Software',
          workMode: 'Hybrid',
          vacanciesCount: 4,
          description:
              'Architect, build, and deploy high-performance cross-platform applications across iOS, Android, and Web using Flutter and cloud backends.',
          postedAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        JobModel(
          id: '',
          title: 'Full Stack Node.js & React Engineer',
          titleTamil: 'முழு அடுக்கு மென்பொருள் பொறியாளர்',
          companyName: 'Freshworks Technologies',
          locationCity: 'Chennai / Bengaluru',
          salaryText: '₹10 - 16 LPA',
          category: 'IT & Software',
          workMode: 'Remote',
          vacanciesCount: 2,
          description:
              'Develop scalable microservices, serverless APIs on Node.js, and responsive web portals with TypeScript and React.',
          postedAt: DateTime.now().subtract(const Duration(hours: 6)),
        ),
        JobModel(
          id: '',
          title: 'Embedded Systems & IoT Hardware Engineer',
          titleTamil: 'எம்பெடட் சிஸ்டம்ஸ் பொறியாளர்',
          companyName: 'Bosch Engineering',
          locationCity: 'Coimbatore',
          salaryText: '₹6 - 9 LPA',
          category: 'Engineering & Manufacturing',
          workMode: 'On-Site',
          vacanciesCount: 3,
          description:
              'Design microcontroller circuits, firmware development in Embedded C/C++, and hardware integration for automotive IoT solutions.',
          postedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        JobModel(
          id: '',
          title: 'Senior UI/UX Product Designer',
          titleTamil: 'தயாரிப்பு வடிவமைப்பு நிபுணர்',
          companyName: 'Swiggy Design Labs',
          locationCity: 'Bengaluru / Remote',
          salaryText: '₹14 - 20 LPA',
          category: 'UI/UX & Product Design',
          workMode: 'Remote',
          vacanciesCount: 1,
          description:
              'Own design systems, micro-interactions, responsive prototypes, and human-centered user experiences for millions of active users.',
          postedAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
        ),
        JobModel(
          id: '',
          title: 'Senior Financial Analyst & Tally Consultant',
          titleTamil: 'நிதி ஆய்வாளர்',
          companyName: 'Deloitte India',
          locationCity: 'Erode / Coimbatore',
          salaryText: '₹5 - 8 LPA',
          category: 'Finance & Accounting',
          workMode: 'On-Site',
          vacanciesCount: 2,
          description:
              'Corporate audit management, GST filing compliance, financial forecasting, and automated accounting operations.',
          postedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        JobModel(
          id: '',
          title: 'Digital Marketing & Growth Strategist',
          titleTamil: 'டிஜிட்டல் மார்க்கெட்டிங்',
          companyName: 'Career360 Media Group',
          locationCity: 'Salem / Madurai',
          salaryText: '₹4.5 - 7 LPA',
          category: 'Sales & Marketing',
          workMode: 'Hybrid',
          vacanciesCount: 2,
          description:
              'Lead search engine marketing, performance ads on Google & Meta, conversion rate optimization, and brand storytelling.',
          postedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ];

      for (final job in initialJobs) {
        await _jobsRef.add(job.toMap());
      }
      debugPrint('[FirestoreService] Successfully seeded initial live jobs.');
    } catch (e) {
      debugPrint('[FirestoreService] Notice during job seeding: $e');
    }
  }

  /// 4. Submit a Live Application to Firestore
  Future<bool> applyToJob({
    required String jobId,
    required JobModel job,
    required String candidateUid,
    required Map<String, dynamic> candidateProfile,
  }) async {
    try {
      // 1. Create document in applications collection
      await _applicationsRef.add({
        'jobId': jobId,
        'jobTitle': job.title,
        'companyName': job.companyName,
        'locationCity': job.locationCity,
        'salaryText': job.salaryText,
        'employerUid': job.employerUid,
        'candidateUid': candidateUid,
        'candidateName': candidateProfile['fullName'] ?? candidateProfile['displayName'] ?? 'Applicant',
        'candidateEmail': candidateProfile['email'] ?? '',
        'candidatePhone': candidateProfile['phone'] ?? '',
        'education': candidateProfile['qualification'] ?? candidateProfile['educationLevel'] ?? '',
        'experienceYears': candidateProfile['experienceYears'] ?? '0',
        'status': 'Applied',
        'appliedAt': FieldValue.serverTimestamp(),
      });

      // 2. Add to user's applied jobs set
      final userDoc = _usersRef.doc(candidateUid);
      await userDoc.set({
        'appliedJobIds': FieldValue.arrayUnion([jobId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[FirestoreService] Application recorded for job: $jobId');
      return true;
    } catch (e) {
      debugPrint('[FirestoreService] Error submitting application: $e');
      return false;
    }
  }

  /// 5. Toggle Bookmark / Saved Job in Firestore
  Future<bool> toggleSaveJob({
    required String candidateUid,
    required String jobId,
    required bool isSaved,
  }) async {
    try {
      final userDoc = _usersRef.doc(candidateUid);
      if (isSaved) {
        // Remove from saved
        await userDoc.set({
          'savedJobIds': FieldValue.arrayRemove([jobId]),
        }, SetOptions(merge: true));
        return false;
      } else {
        // Add to saved
        await userDoc.set({
          'savedJobIds': FieldValue.arrayUnion([jobId]),
        }, SetOptions(merge: true));
        return true;
      }
    } catch (e) {
      debugPrint('[FirestoreService] Error toggling saved job: $e');
      return isSaved;
    }
  }

  /// 6. Stream Live Saved Job IDs for a Candidate
  Stream<Set<String>> streamSavedJobIds(String candidateUid) {
    if (candidateUid.isEmpty) {
      return Stream.value({});
    }
    return _usersRef.doc(candidateUid).snapshots().map((doc) {
      if (!doc.exists) return <String>{};
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final list = data['savedJobIds'] as List<dynamic>? ?? [];
      return list.map((e) => e.toString()).toSet();
    });
  }

  /// 7. Stream Live Applied Job IDs for a Candidate
  Stream<Set<String>> streamAppliedJobIds(String candidateUid) {
    if (candidateUid.isEmpty) {
      return Stream.value({});
    }
    return _usersRef.doc(candidateUid).snapshots().map((doc) {
      if (!doc.exists) return <String>{};
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final list = data['appliedJobIds'] as List<dynamic>? ?? [];
      return list.map((e) => e.toString()).toSet();
    });
  }

  /// 8. Stream Candidate Submitted Applications
  Stream<List<Map<String, dynamic>>> streamCandidateApplications(String candidateUid) {
    if (candidateUid.isEmpty) return Stream.value([]);
    return _applicationsRef
        .where('candidateUid', isEqualTo: candidateUid)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// 9. Stream Recruiter Applicants
  Stream<List<Map<String, dynamic>>> streamRecruiterApplicants({String? employerUid}) {
    Query q = _applicationsRef.orderBy('appliedAt', descending: true);
    if (employerUid != null && employerUid.isNotEmpty) {
      q = q.where('employerUid', isEqualTo: employerUid);
    }
    return q.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// 10. Stream Live Candidate Profile from Firestore
  Stream<Map<String, dynamic>?> streamCandidateProfile(String uid) {
    if (uid.isEmpty) return Stream.value(null);
    return _candidatesRef.doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    });
  }
}
