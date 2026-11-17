import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/job_model.dart';
import '../../data/sample_jobs.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

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

  static Future<Map<String, dynamic>?> getCandidateProfile(
    String userId,
  ) async {
    final row = await client
        .from('candidate_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    final account = await client
        .from('profiles')
        .select('email,phone')
        .eq('id', userId)
        .maybeSingle();
    return candidateView(row, account);
  }

  static Map<String, dynamic> candidateView(
    Map<String, dynamic> row,
    Map<String, dynamic>? account,
  ) {
    final personal = Map<String, dynamic>.from(
      row['personal_details'] as Map? ?? {},
    );
    final education = Map<String, dynamic>.from(row['education'] as Map? ?? {});
    final experience = Map<String, dynamic>.from(
      row['experience'] as Map? ?? {},
    );
    final birthYear = personal['birthYear'] as int?;
    final birthMonth = personal['birthMonth']?.toString() ?? '';
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final now = DateTime.now();
    final monthIndex = months.indexOf(birthMonth);
    final age = birthYear == null || monthIndex < 0
        ? null
        : now.year - birthYear - (now.month < monthIndex + 1 ? 1 : 0);
    return {
      ...row,
      ...personal,
      ...education,
      ...experience,
      'fullName': row['full_name'],
      'profilePhotoUrl': row['profile_photo_url'],
      'phone': account?['phone'],
      'email': account?['email'],
      'preferredJobTitles': row['preferred_job_titles'] ?? <String>[],
      'age': age,
    };
  }

  static Future<void> saveCandidateOnboardingStep({
    required String userId,
    required String email,
    required int step,
    required Map<String, dynamic> values,
  }) async {
    if (step < 1 || step > 4 || client.auth.currentUser?.id != userId) {
      throw StateError('A candidate session is required to save this step.');
    }
    final changes = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (step == 1) {
      await client.from('profiles').upsert({
        'id': userId,
        'email': email.toLowerCase().trim(),
        'phone': values['phone'],
        'role': 'CANDIDATE',
        'updated_at': changes['updated_at'],
      });
      changes.addAll({
        'full_name': values['fullName'],
        'district': values['district'],
        'personal_details': {
          'gender': values['gender'],
          'maritalStatus': values['maritalStatus'],
          'state': values['state'],
          'birthMonth': values['birthMonth'],
          'birthYear': values['birthYear'],
        },
      });
    } else if (step == 2) {
      changes['education'] = {
        'educationLevel': values['educationLevel'],
        'qualification': values['qualification'],
        'collegeOrSchool': values['collegeOrSchool'],
        'graduationYear': values['graduationYear'],
      };
    } else if (step == 3) {
      changes['preferred_job_titles'] = values['preferredJobTitles'];
    } else {
      changes['experience'] = {
        'hasExperience': values['hasExperience'],
        'experienceYears': values['experienceYears'],
        'experienceMonths': values['experienceMonths'],
        'lastCompany': values['lastCompany'],
        'lastJobTitle': values['lastJobTitle'],
        'salary': values['salary'],
        'noticePeriod': values['noticePeriod'],
      };
      changes['onboarding_completed_at'] = DateTime.now().toIso8601String();
    }
    final existing = await client
        .from('candidate_profiles')
        .select('id,onboarding_step')
        .eq('user_id', userId)
        .maybeSingle();
    if (existing == null && step != 1) {
      throw StateError('Save your personal details before continuing.');
    }
    changes['onboarding_step'] =
        (existing?['onboarding_step'] as int? ?? 0) > step
        ? existing!['onboarding_step']
        : step;
    if (existing == null) {
      await client.from('candidate_profiles').insert({
        'user_id': userId,
        ...changes,
      });
    } else {
      final updated = await client
          .from('candidate_profiles')
          .update(changes)
          .eq('user_id', userId)
          .select('id')
          .maybeSingle();
      if (updated == null) throw StateError('Could not save your profile.');
    }
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
    final contentType = switch (fileExtension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    await client.storage
        .from('profile-photos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    final url = client.storage.from('profile-photos').getPublicUrl(path);
    return '$url?v=${DateTime.now().microsecondsSinceEpoch}';
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
    required String designation,
    required String industry,
    required String companySize,
    required String description,
    required String whatsappPhone,
    required bool whatsappSameAsPhone,
    required String website,
    required String address,
    required String state,
    required String postalCode,
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
      'industry': industry,
      'company_size': companySize,
      'description': description,
      'whatsapp_phone': whatsappPhone,
      'whatsapp_same_as_phone': whatsappSameAsPhone,
      'website': website,
      'address': address,
      'state': state,
      'postal_code': postalCode,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (logoUrl != null) payload['logo_url'] = logoUrl;

    await client
        .from('employers')
        .upsert(payload, onConflict: 'user_id')
        .select('id')
        .single();
  }

  // ---------------------------------------------------------------------------
  // Jobs & Applications (Realtime & Queries)
  // ---------------------------------------------------------------------------

  static Stream<List<Map<String, dynamic>>> streamPublishedJobs({
    String? district,
  }) {
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

  static Stream<List<Map<String, dynamic>>> streamEmployerJobs(
    String employerId,
  ) {
    return client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('employer_id', employerId)
        .order('created_at', ascending: false);
  }

  static Stream<List<Map<String, dynamic>>> streamEmployerApplications(
    String employerId,
  ) {
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
    if (interviewDate != null) {
      payload['interview_date'] = interviewDate.toIso8601String();
    }
    if (notes != null) payload['notes'] = notes;

    await client
        .from('job_applications')
        .update(payload)
        .eq('id', applicationId);
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

  static Future<void> registerDeviceFcmToken(
    String fcmToken, {
    String deviceType = 'android',
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null || fcmToken.trim().isEmpty) return;
    try {
      await client
          .from('profiles')
          .update({
            'fcm_token': fcmToken.trim(),
            'device_type': deviceType,
            'last_active_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Realtime Database & Job Operations (Supabase PostgreSQL)
  // ---------------------------------------------------------------------------

  static final Map<String, Set<String>> _savedJobsCache = {};
  static final StreamController<Map<String, Set<String>>> _savedJobsController =
      StreamController<Map<String, Set<String>>>.broadcast();

  Stream<List<JobModel>> streamJobs({
    String? category,
    String? locationCity,
    String? searchQuery,
  }) async* {
    List<JobModel> filterJobs(List<JobModel> jobs) {
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
          return job.title.toLowerCase().contains(q) ||
              job.companyName.toLowerCase().contains(q) ||
              job.locationCity.toLowerCase().contains(q) ||
              job.category.toLowerCase().contains(q) ||
              job.description.toLowerCase().contains(q);
        }
        return true;
      }).toList();
    }

    try {
      final rows = await client
          .from('jobs')
          .select()
          .order('created_at', ascending: false);
      final liveJobs = (rows as List)
          .map((r) => JobModel.fromMap(r as Map<String, dynamic>))
          .toList();
      final filtered = filterJobs(liveJobs);
      if (filtered.isNotEmpty || kReleaseMode) {
        yield filtered;
      } else {
        yield filterJobs(SampleJobs.all);
      }
    } catch (_) {
      yield filterJobs(SampleJobs.all);
    }

    try {
      yield* client
          .from('jobs')
          .stream(primaryKey: ['id'])
          .map((rows) {
            final liveJobs = rows.map((row) => JobModel.fromMap(row)).toList();
            final filtered = filterJobs(liveJobs);
            if (filtered.isNotEmpty || kReleaseMode) {
              return filtered;
            }
            return filterJobs(SampleJobs.all);
          })
          .handleError((err) {
            debugPrint('[Jobs Realtime Notice]: $err');
          });
    } catch (_) {}
  }

  Future<String> createJobPost(JobModel job) async {
    try {
      final res = await client
          .from('jobs')
          .insert({
            'title': job.title,
            'category': job.category,
            'description': job.description,
            'location_city': job.locationCity,
            'salary_text': job.salaryText,
            'work_mode': job.workMode,
            'vacancies_count': job.vacanciesCount,
            'is_verified': job.isVerified,
            'employer_id': job.employerUid,
            'status': 'PUBLISHED',
          })
          .select()
          .single();
      return res['id']?.toString() ?? '';
    } catch (e) {
      debugPrint('[SupabaseService] Error creating job: $e');
      rethrow;
    }
  }

  Future<bool> applyToJob({
    required String jobId,
    required JobModel job,
    required String candidateUid,
    required Map<String, dynamic> candidateProfile,
  }) async {
    if (job.isDemo) return false;
    try {
      await client.from('job_applications').insert({
        'job_id': jobId,
        'job_title': job.title,
        'company_name': job.companyName,
        'employer_id': job.employerUid ?? '',
        'candidate_id': candidateUid,
        'applicant_name':
            candidateProfile['fullName'] ??
            candidateProfile['displayName'] ??
            'Applicant',
        'applicant_phone': candidateProfile['phone'] ?? '',
        'applicant_district':
            candidateProfile['district'] ??
            candidateProfile['locationCity'] ??
            '',
        'status': 'SUBMITTED',
      });
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] Error applying to job: $e');
      return false;
    }
  }

  Future<bool> toggleSaveJob({
    required String candidateUid,
    required String jobId,
    required bool isSaved,
  }) async {
    final current = _savedJobsCache[candidateUid] ?? <String>{};
    if (isSaved) {
      current.remove(jobId);
    } else {
      current.add(jobId);
    }
    _savedJobsCache[candidateUid] = current;
    _savedJobsController.add(Map.from(_savedJobsCache));
    return !isSaved;
  }

  Stream<Set<String>> streamSavedJobIds(String candidateUid) {
    if (candidateUid.isEmpty) return Stream.value(<String>{});
    return _savedJobsController.stream
        .map((cache) => cache[candidateUid] ?? <String>{})
        .startWith(_savedJobsCache[candidateUid] ?? <String>{});
  }

  Stream<Set<String>> streamAppliedJobIds(String candidateUid) {
    if (candidateUid.isEmpty) return Stream.value(<String>{});
    try {
      return client
          .from('job_applications')
          .stream(primaryKey: ['id'])
          .eq('candidate_id', candidateUid)
          .map(
            (rows) => rows
                .map((r) => r['job_id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toSet(),
          );
    } catch (_) {
      return Stream.value(<String>{});
    }
  }

  Stream<List<Map<String, dynamic>>> streamCandidateApplications(
    String candidateUid,
  ) {
    if (candidateUid.isEmpty) return Stream.value([]);
    try {
      return client
          .from('job_applications')
          .stream(primaryKey: ['id'])
          .eq('candidate_id', candidateUid)
          .order('created_at', ascending: false);
    } catch (_) {
      return Stream.value([]);
    }
  }

  Stream<List<Map<String, dynamic>>> streamRecruiterApplicants({
    required String employerUid,
  }) {
    if (employerUid.isEmpty) return Stream.value([]);
    try {
      return client
          .from('job_applications')
          .stream(primaryKey: ['id'])
          .eq('employer_id', employerUid)
          .order('created_at', ascending: false);
    } catch (_) {
      return Stream.value([]);
    }
  }

  Stream<Map<String, dynamic>?> streamCandidateProfile(String uid) async* {
    if (uid.isEmpty) {
      yield null;
      return;
    }
    yield await getCandidateProfile(uid);
    yield* client
        .from('candidate_profiles')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .asyncMap((rows) async {
          if (rows.isEmpty) return null;
          final account = await client
              .from('profiles')
              .select('email,phone')
              .eq('id', uid)
              .maybeSingle();
          return candidateView(rows.first, account);
        });
  }

  Stream<String?> streamCandidatePublicPhoto(String uid) {
    if (uid.isEmpty) return Stream.value(null);
    return streamCandidateProfile(uid)
        .map((p) => p?['profile_photo_url'] as String?);
  }
}

extension _StreamStartWith<T> on Stream<T> {
  Stream<T> startWith(T initial) async* {
    yield initial;
    yield* this;
  }
}
