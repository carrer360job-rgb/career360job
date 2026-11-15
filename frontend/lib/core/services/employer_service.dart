import 'employer_api_service.dart';
import 'supabase_service.dart';
import 'app_auth_bridge.dart';

import '../../data/models/employer_profile.dart';
import '../../data/models/job_model.dart';

class EmployerService {
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

  Future<void> updateContact(String uid, Map<String, dynamic> changes) async {
    try {
      await SupabaseService.client
          .from('employers')
          .update({
            ...changes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', uid);
    } catch (_) {}
  }

  Stream<List<JobModel>> watchJobs(String uid) {
    return SupabaseService.streamEmployerJobs(uid).map((rows) {
      final jobs = rows.map((r) => JobModel.fromMap(r)).toList();
      jobs.sort((a, b) => b.postedAt.compareTo(a.postedAt));
      return jobs;
    });
  }

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

  Stream<List<Map<String, dynamic>>> watchPayments(String uid) {
    try {
      return SupabaseService.client
          .from('employer_orders')
          .stream(primaryKey: ['id'])
          .eq('employer_id', uid)
          .order('created_at', ascending: false);
    } catch (_) {
      return Stream.value([]);
    }
  }

}
