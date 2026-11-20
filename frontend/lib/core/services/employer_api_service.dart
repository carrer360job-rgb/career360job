import 'dart:convert';

import 'package:http/http.dart' as http;

import 'supabase_service.dart';

class EmployerApiService {
  static const _defaultBaseUrl = 'https://career360job-backend.vercel.app';
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static String get _baseUrl =>
      _configuredBaseUrl.isEmpty ? _defaultBaseUrl : _configuredBaseUrl;

  Uri _uri(String path) =>
      Uri.parse('${_baseUrl.replaceAll(RegExp(r"/+$"), "")}/api/employer$path');

  Future<Map<String, String>> _headers() async {
    final supabaseToken =
        SupabaseService.client.auth.currentSession?.accessToken;
    if (supabaseToken != null && supabaseToken.isNotEmpty) {
      return {
        'Authorization': 'Bearer $supabaseToken',
        'Content-Type': 'application/json',
      };
    }
    throw StateError('Sign in again to continue.');
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
    bool authenticated = true,
  ]) async {
    final headers = authenticated
        ? await _headers()
        : {'Content-Type': 'application/json'};
    final request = http.Request(method, _uri(path));
    request.headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final streamed = await request.send().timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamed)
        .timeout(const Duration(seconds: 15));
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw StateError('The server returned an unreadable response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = data['error'];
      final message = error is Map ? error['message'] : null;
      throw StateError(
        message is String ? message : 'Request failed. Try again.',
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> plans() async {
    return _request('GET', '/plans', null, false);
  }

  Future<Map<String, dynamic>> createOrder(
    String planId,
    int planVersion,
  ) async {
    return _request('POST', '/orders', {
      'planId': planId,
      'planVersion': planVersion,
    });
  }

  Future<void> verifyPayment(
    String orderId,
    String paymentId,
    String signature,
  ) async {
    await _request('POST', '/orders/verify', {
      'orderId': orderId,
      'paymentId': paymentId,
      'signature': signature,
    });
  }

  Future<void> markPaymentFailed(String orderId, String code) async {
    await _request('POST', '/orders/failure', {
      'orderId': orderId,
      'code': code,
    });
  }

  Future<void> publishJob(Map<String, dynamic> fields) async {
    await _request('POST', '/jobs', fields);
  }

  Future<void> editJob(String jobId, Map<String, dynamic> fields) async {
    await _request('PATCH', '/jobs/${Uri.encodeComponent(jobId)}', fields);
  }

  Future<void> closeJob(String jobId) async {
    await _request('POST', '/jobs/${Uri.encodeComponent(jobId)}/close');
  }

  Future<void> updateApplication(String id, String status) async {
    await _request('PATCH', '/applications/${Uri.encodeComponent(id)}/status', {
      'status': status,
    });
  }

  Future<Map<String, dynamic>> entitlement() => _request('GET', '/entitlement');

  Future<Map<String, dynamic>> applications() =>
      _request('GET', '/applications');

  Future<Map<String, dynamic>> viewApplicant(String id) async {
    final data = await _request(
      'POST',
      '/applications/${Uri.encodeComponent(id)}/view',
    );
    return (data['profile'] as Map).cast<String, dynamic>();
  }
}
