import 'package:cloud_firestore/cloud_firestore.dart';
import 'employer_api_service.dart';
import 'supabase_service.dart';
import 'app_auth_bridge.dart';

import '../../data/models/employer_profile.dart';
import '../../data/models/job_model.dart';

class EmployerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<EmployerProfile?> watchProfile(String uid) {
    return SupabaseService.client
        .from('employers')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .map((rows) {
          if (rows.isEmpty) return null;
          return EmployerProfile.fromMap(rows.first, uid);
        });
  }

  Future<void> register(Map<String, dynamic> details) async {
    final user = AppAuthBridge.currentUser;
    if (user == null || user.email == null) {
      throw StateError('Sign in with a valid account to register a company.');
    }
    await SupabaseService.upsertEmployer(
      userId: user.uid,
      companyName: details['companyName'] ?? 'Company',
      contactName: details['contactName'] ?? '',
      phone: details['phone'] ?? '',
      email: user.email!,
      district: details['district'] ?? 'Chennai',
      designation: details['designation'],
      city: details['city'],
      logoUrl: details['logoUrl'],
    );
    await SupabaseService.client.from('profiles').upsert({
      'id': user.uid,
      'email': user.email!.toLowerCase().trim(),
      'role': 'EMPLOYER',
      'status': 'ACTIVE',
      'updated_at': DateTime.now().toIso8601String(),
    });
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
    while (AppAuthBridge.currentUser?.uid == uid) {
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
