import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'employer_api_service.dart';

import '../../data/models/employer_profile.dart';
import '../../data/models/job_model.dart';

class EmployerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<EmployerProfile?> watchProfile(String uid) => _firestore
      .collection('employers')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? EmployerProfile.fromFirestore(doc) : null);

  Future<void> register(Map<String, dynamic> details) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified || user.email == null) {
      throw StateError('Sign in with a verified email to register a company.');
    }
    final employerRef = _firestore.collection('employers').doc(user.uid);
    final userRef = _firestore.collection('users').doc(user.uid);
    final batch = _firestore.batch();
    batch.set(employerRef, {
      'uid': user.uid,
      'email': user.email!.toLowerCase().trim(),
      ...details,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(userRef, {
      'uid': user.uid,
      'email': user.email!.toLowerCase().trim(),
      'role': 'employer',
      'displayName': details['contactName'],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> updateContact(String uid, Map<String, dynamic> changes) =>
      _firestore.collection('employers').doc(uid).update({
        ...changes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Stream<List<JobModel>> watchJobs(String uid) => _firestore
      .collection('jobs')
      .where('employerUid', isEqualTo: uid)
      .snapshots()
      .map((snapshot) {
        final jobs = snapshot.docs.map(JobModel.fromFirestore).toList();
        jobs.sort((a, b) => b.postedAt.compareTo(a.postedAt));
        return jobs;
      });

  Stream<List<Map<String, dynamic>>> watchApplications(String uid) async* {
    while (FirebaseAuth.instance.currentUser?.uid == uid) {
      final data = await EmployerApiService().applications();
      final raw = data['applications'];
      yield raw is List
          ? raw.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList()
          : <Map<String, dynamic>>[];
      await Future<void>.delayed(const Duration(seconds: 20));
    }
  }

  Stream<List<Map<String, dynamic>>> watchPayments(String uid) => _firestore
      .collection('employer_orders')
      .where('employerUid', isEqualTo: uid)
      .snapshots()
      .map((snapshot) {
        final orders = snapshot.docs
            .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
            .toList();
        orders.sort((a, b) {
          final aAt = a['createdAt'] is Timestamp
              ? (a['createdAt'] as Timestamp).millisecondsSinceEpoch
              : 0;
          final bAt = b['createdAt'] is Timestamp
              ? (b['createdAt'] as Timestamp).millisecondsSinceEpoch
              : 0;
          return bAt.compareTo(aAt);
        });
        return orders;
      });

}
