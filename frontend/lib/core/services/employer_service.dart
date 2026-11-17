import 'package:flutter/foundation.dart';

import 'employer_api_service.dart';
import 'supabase_service.dart';
import 'app_auth_bridge.dart';

import '../../data/models/employer_profile.dart';
import '../../data/models/job_model.dart';

class EmployerService {
  Stream<EmployerProfile?> watchProfile(String uid) async* {
    final row = await SupabaseService.client
        .from('employers')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    yield row == null ? null : EmployerProfile.fromMap(row, uid);

    yield* SupabaseService.client
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
    await SupabaseService.client.from('profiles').upsert({
      'id': user.uid,
      'email': user.email!.toLowerCase().trim(),
      'role': 'EMPLOYER',
      'updated_at': DateTime.now().toIso8601String(),
    });
    await SupabaseService.upsertEmployer(
      userId: user.uid,
      companyName: details['companyName'] ?? 'Company',
      contactName: details['contactName'] ?? '',
      phone: details['phone'] ?? '',
      email: user.email!,
      district: details['district'] ?? 'Chennai',
      designation: details['designation'] ?? '',
      industry: details['industry'] ?? '',
      companySize: details['companySize'] ?? '',
      description: details['description'] ?? '',
      whatsappPhone: details['whatsappPhone'] ?? '',
      whatsappSameAsPhone: details['whatsappSameAsPhone'] == true,
      website: details['website'] ?? '',
      address: details['address'] ?? '',
      state: details['state'] ?? '',
      postalCode: details['postalCode'] ?? '',
      city: details['city'],
      logoUrl: details['logoUrl'],
    );
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> changes) async {
    const columns = {
      'companyName': 'company_name',
      'contactName': 'contact_name',
      'designation': 'designation',
      'industry': 'industry',
      'companySize': 'company_size',
      'description': 'description',
      'phone': 'phone',
      'whatsappPhone': 'whatsapp_phone',
      'whatsappSameAsPhone': 'whatsapp_same_as_phone',
      'website': 'website',
      'address': 'address',
      'state': 'state',
      'district': 'district',
      'postalCode': 'postal_code',
    };
    final payload = <String, dynamic>{
      for (final entry in changes.entries)
        if (columns.containsKey(entry.key)) columns[entry.key]!: entry.value,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final updated = await SupabaseService.client
        .from('employers')
        .update(payload)
        .eq('user_id', uid)
        .select('id')
        .maybeSingle();
    if (updated == null) {
      throw StateError('Company details could not be updated. Try again.');
    }
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
          ? raw
                .whereType<Map>()
                .map((item) => item.cast<String, dynamic>())
                .toList()
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
          .order('created_at', ascending: false)
          .handleError((err) {
            debugPrint('[EmployerService] watchPayments error: $err');
          });
    } catch (_) {
      return Stream.value([]);
    }
  }
}
