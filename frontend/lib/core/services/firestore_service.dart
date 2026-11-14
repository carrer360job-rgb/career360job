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
  CollectionReference get _applicationsRef =>
      _firestore.collection('applications');
  CollectionReference get _usersRef => _firestore.collection('users');
  CollectionReference get _candidatesRef => _firestore.collection('candidates');

  /// 1. Real-Time Stream of Live Jobs from Cloud Firestore
  Stream<List<JobModel>> streamJobs({
    String? category,
    String? locationCity,
    String? searchQuery,
  }) {
    Query query = _jobsRef;
    if (category != null && category != 'All' && category != 'All Categories') {
      query = query.where('category', isEqualTo: category);
    }
    query = query.orderBy('postedAt', descending: true);

    return query.snapshots().map((snapshot) {
      final jobs = snapshot.docs
          .map((doc) => JobModel.fromFirestore(doc))
          .toList();

      return jobs.where((job) {
        if (!job.isOpen) return false;
        if (locationCity != null &&
            locationCity != 'All Locations' &&
            !job.isStatewide &&
            !job.locationCity.toLowerCase().contains(
              locationCity.toLowerCase(),
            )) {
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
          final matchesLoc = job.isStatewide || job.locationCity.toLowerCase().contains(q);
          final matchesCategory = job.category.toLowerCase().contains(q);
          final matchesDescription = job.description.toLowerCase().contains(q);
          return matchesTitle ||
              matchesCompany ||
              matchesLoc ||
              matchesCategory ||
              matchesDescription;
        }
        return true;
      }).toList()
        ..sort((a, b) {
          if (a.isFeatured != b.isFeatured) {
            return a.isFeatured ? -1 : 1;
          }
          return b.postedAt.compareTo(a.postedAt);
        });
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

  /// 4. Submit a Live Application to Firestore
  Future<bool> applyToJob({
    required String jobId,
    required JobModel job,
    required String candidateUid,
    required Map<String, dynamic> candidateProfile,
  }) async {
    if (job.isDemo) return false;
    try {
      final batch = _firestore.batch();
      final applicationRef = _applicationsRef.doc();
      batch.set(applicationRef, {
        'jobId': jobId,
        'jobTitle': job.title,
        'companyName': job.companyName,
        'locationCity': job.locationCity,
        'salaryText': job.salaryText,
        'employerUid': job.employerUid,
        'candidateUid': candidateUid,
        'candidateName':
            candidateProfile['fullName'] ??
            candidateProfile['displayName'] ??
            'Applicant',
        'candidateEmail': candidateProfile['email'] ?? '',
        'candidatePhone': candidateProfile['phone'] ?? '',
        'education':
            candidateProfile['qualification'] ??
            candidateProfile['educationLevel'] ??
            '',
        'experienceYears': candidateProfile['experienceYears'] ?? '0',
        'status': 'Applied',
        'appliedAt': FieldValue.serverTimestamp(),
      });

      final userDoc = _usersRef.doc(candidateUid);
      batch.set(userDoc, {
        'uid': candidateUid,
        'email': candidateProfile['email'] ?? '',
        'role': 'candidate',
        'appliedJobIds': FieldValue.arrayUnion([jobId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await batch.commit();

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
  Stream<List<Map<String, dynamic>>> streamCandidateApplications(
    String candidateUid,
  ) {
    if (candidateUid.isEmpty) return Stream.value([]);
    return _applicationsRef
        .where('candidateUid', isEqualTo: candidateUid)
        .snapshots()
        .map((snapshot) {
          final applications = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList();
          applications.sort((a, b) {
            final aTime = a['appliedAt'] is Timestamp
                ? (a['appliedAt'] as Timestamp).millisecondsSinceEpoch
                : 0;
            final bTime = b['appliedAt'] is Timestamp
                ? (b['appliedAt'] as Timestamp).millisecondsSinceEpoch
                : 0;
            return bTime.compareTo(aTime);
          });
          return applications;
        });
  }

  /// 9. Stream Recruiter Applicants
  Stream<List<Map<String, dynamic>>> streamRecruiterApplicants({
    required String employerUid,
  }) {
    if (employerUid.isEmpty) return Stream.value([]);
    return _applicationsRef
        .where('employerUid', isEqualTo: employerUid)
        .snapshots()
        .map((snapshot) {
          final applicants = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList();
          applicants.sort((a, b) {
            final aTime = a['appliedAt'] is Timestamp
                ? (a['appliedAt'] as Timestamp).millisecondsSinceEpoch
                : 0;
            final bTime = b['appliedAt'] is Timestamp
                ? (b['appliedAt'] as Timestamp).millisecondsSinceEpoch
                : 0;
            return bTime.compareTo(aTime);
          });
          return applicants;
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

  Stream<String?> streamCandidatePublicPhoto(String uid) {
    if (uid.isEmpty) return Stream.value(null);
    return _firestore
        .collection('candidate_public_profiles')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data()?['photoUrl'] as String?);
  }

  Future<void> updateCandidateProfile({
    required String uid,
    required Map<String, dynamic> updates,
  }) async {
    await _candidatesRef.doc(uid).set({
      'uid': uid,
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
