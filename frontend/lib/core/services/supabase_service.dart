import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://nnilnwhjpkllmocptmks.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5uaWxud2hqcGtsbG1vY3B0bWtzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ3MzEzNjIsImV4cCI6MjExMDMwNzM2Mn0.L4WpFSA5Gi3QIjldy_LdbptrtfDLGoYpx7PkLwqYHyI';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Candidate Profile & Resume Operations
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>?> getCandidateProfile(String userId) async {
    try {
      final data = await client
          .from('candidate_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return data;
    } catch (_) {
      return null;
    }
  }

  static Future<void> upsertCandidateProfile({
    required String userId,
    required String fullName,
    required String district,
    String? city,
    String? profilePhotoUrl,
    Map<String, dynamic>? education,
    Map<String, dynamic>? experience,
    List<String>? skills,
    String? resumeUrl,
  }) async {
    final payload = <String, dynamic>{
      'user_id': userId,
      'full_name': fullName,
      'district': district,
      'city': city,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (profilePhotoUrl != null) payload['profile_photo_url'] = profilePhotoUrl;
    if (education != null) payload['education'] = education;
    if (experience != null) payload['experience'] = experience;
    if (skills != null) payload['skills'] = skills;
    if (resumeUrl != null) payload['resume_url'] = resumeUrl;

    await client.from('candidate_profiles').upsert(payload, onConflict: 'user_id');
  }

  static Future<String> uploadProfilePhoto({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    if (bytes.lengthInBytes > 3 * 1024 * 1024) {
      throw Exception('Profile photo must be 3 MB or less.');
    }
    final path = '$userId/avatar.$fileExtension';
    await client.storage.from('profile-photos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return client.storage.from('profile-photos').getPublicUrl(path);
  }

  static Future<String> uploadResume({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      throw Exception('Resume file must be 5 MB or less.');
    }
    final sanitized = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '$userId/$sanitized';
    await client.storage.from('resumes').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return await client.storage.from('resumes').createSignedUrl(
          path,
          60 * 60 * 24 * 30, // 30 days validity
        );
  }

  // ---------------------------------------------------------------------------
  // Employer & Company Operations
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>?> getEmployer(String userId) async {
    try {
      final data = await client
          .from('employers')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return data;
    } catch (_) {
      return null;
    }
  }

  static Future<void> upsertEmployer({
    required String userId,
    required String companyName,
    required String contactName,
    required String phone,
    required String email,
    required String district,
    String? designation,
    String? city,
    String? logoUrl,
  }) async {
    final payload = <String, dynamic>{
      'user_id': userId,
      'company_name': companyName,
      'contact_name': contactName,
      'phone': phone,
      'email': email,
      'district': district,
      'designation': designation,
      'city': city,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (logoUrl != null) payload['logo_url'] = logoUrl;

    await client.from('employers').upsert(payload, onConflict: 'user_id');
  }

  // ---------------------------------------------------------------------------
  // Jobs & Applications (Realtime & Queries)
  // ---------------------------------------------------------------------------

  static Stream<List<Map<String, dynamic>>> streamPublishedJobs({String? district}) {
    final query = client.from('jobs').stream(primaryKey: ['id']);
    return query.map((rows) {
      return rows.where((job) {
        final isPublished = job['status'] == 'PUBLISHED';
        if (!isPublished) return false;
        if (district == null || district.isEmpty) return true;
        final reach = job['reach']?.toString().toLowerCase() ?? 'district';
        final jobDistrict = job['district']?.toString().toLowerCase() ?? '';
        return reach == 'statewide' || jobDistrict == district.toLowerCase();
      }).toList();
    });
  }

  static Stream<List<Map<String, dynamic>>> streamEmployerJobs(String employerId) {
    return client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('employer_id', employerId)
        .order('created_at', ascending: false);
  }

  static Stream<List<Map<String, dynamic>>> streamEmployerApplications(String employerId) {
    return client
        .from('job_applications')
        .stream(primaryKey: ['id'])
        .eq('employer_id', employerId)
        .order('created_at', ascending: false);
  }

  static Future<void> postJob(Map<String, dynamic> jobData) async {
    await client.from('jobs').insert(jobData);
  }

  static Future<void> applyForJob({
    required String jobId,
    required String candidateId,
    required String employerId,
    required String applicantName,
    required String applicantPhone,
    String? applicantDistrict,
    String? resumeUrl,
    String? notes,
  }) async {
    await client.from('job_applications').insert({
      'job_id': jobId,
      'candidate_id': candidateId,
      'employer_id': employerId,
      'applicant_name': applicantName,
      'applicant_phone': applicantPhone,
      'applicant_district': applicantDistrict,
      'resume_url': resumeUrl,
      'notes': notes,
      'status': 'SUBMITTED',
    });
  }

  static Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
    DateTime? interviewDate,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (interviewDate != null) payload['interview_date'] = interviewDate.toIso8601String();
    if (notes != null) payload['notes'] = notes;

    await client.from('job_applications').update(payload).eq('id', applicationId);
  }

  // ---------------------------------------------------------------------------
  // Plans & Pricing
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getActivePlans() async {
    final response = await client
        .from('employer_plans')
        .select()
        .eq('is_active', true)
        .order('price_paise', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // ---------------------------------------------------------------------------
  // Push Notification FCM Device Token Registration
  // ---------------------------------------------------------------------------

  static Future<void> registerDeviceFcmToken(String fcmToken, {String deviceType = 'android'}) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null || fcmToken.trim().isEmpty) return;
    try {
      await client.from('profiles').update({
        'fcm_token': fcmToken.trim(),
        'device_type': deviceType,
        'last_active_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (_) {}
  }
}
