import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'supabase_service.dart';

class PlatformContentService {
  static const _defaultBaseUrl = 'https://career360job-backend.vercel.app';
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static String get _baseUrl => _configuredBaseUrl.isEmpty ? _defaultBaseUrl : _configuredBaseUrl;

  Future<List<Map<String, dynamic>>> list(String kind) async {
    final uri = Uri.parse('${_baseUrl.replaceAll(RegExp(r"/+$"), "")}/api/content')
        .replace(queryParameters: {'kind': kind});
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return const [];
    final decoded = jsonDecode(response.body);
    final items = decoded is Map ? decoded['items'] : null;
    if (items is! List) return const [];
    return items.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList();
  }

  Future<void> reportJob(String jobId, String reason, String details) async {
    String? token = SupabaseService.client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || !user.emailVerified) throw StateError('Sign in with a verified account to report a job.');
      token = await user.getIdToken(true);
    }
    if (token == null) throw StateError('Could not verify your session.');
    final uri = Uri.parse('${_baseUrl.replaceAll(RegExp(r"/+$"), "")}/api/employer/jobs/${Uri.encodeComponent(jobId)}/report');
    final response = await http.post(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'reason': reason, 'details': details})).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = jsonDecode(response.body);
      final error = decoded is Map ? decoded['error'] : null;
      final message = error is Map ? error['message'] : null;
      throw StateError(message is String ? message : 'Could not submit your report.');
    }
  }
}
