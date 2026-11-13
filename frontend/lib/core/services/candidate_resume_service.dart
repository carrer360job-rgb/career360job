import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class CandidateResumeService {
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  Uri _endpoint(String path) {
    if (_apiBaseUrl.isEmpty) {
      throw StateError('Set API_BASE_URL to your deployed backend URL.');
    }
    return Uri.parse(
      '${_apiBaseUrl.replaceAll(RegExp(r"/+$"), "")}/api/resumes$path',
    );
  }

  Future<Map<String, String>> _authHeaders(String uid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != uid) {
      throw StateError('Sign in again to manage your resume.');
    }
    final token = await user.getIdToken(true);
    if (token == null) throw StateError('Could not verify your session.');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<void> uploadPdf({
    required String uid,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final headers = await _authHeaders(uid);
    final signed = await http
        .post(
          _endpoint('/sign-upload'),
          headers: headers,
          body: jsonEncode({'fileName': fileName, 'fileSize': bytes.length}),
        )
        .timeout(const Duration(seconds: 20));
    _requireSuccess(signed);
    final authorization = jsonDecode(signed.body) as Map<String, dynamic>;
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(authorization['uploadUrl'] as String),
    );
    request.fields.addAll(
      (authorization['params'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
    request.fields['api_key'] = authorization['apiKey'] as String;
    request.fields['signature'] = authorization['signature'] as String;
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );
    final uploaded = await http.Response.fromStream(
      await request.send().timeout(const Duration(minutes: 2)),
    );
    _requireSuccess(uploaded);
    final asset = jsonDecode(uploaded.body) as Map<String, dynamic>;
    final publicId = asset['public_id'];
    if (publicId is! String ||
        asset['resource_type'] != 'raw' ||
        asset['type'] != 'authenticated') {
      throw StateError('Cloudinary returned an unexpected upload.');
    }
    final finalized = await http
        .post(
          _endpoint('/finalize'),
          headers: headers,
          body: jsonEncode({'publicId': publicId, 'fileName': fileName}),
        )
        .timeout(const Duration(seconds: 30));
    _requireSuccess(finalized);
  }

  Future<void> delete(String uid) async {
    final response = await http
        .delete(_endpoint('/'), headers: await _authHeaders(uid))
        .timeout(const Duration(seconds: 30));
    _requireSuccess(response);
  }

  void _requireSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final error = body['error'];
        final message = error is Map<String, dynamic> ? error['message'] : null;
        if (message is String && message.isNotEmpty) {
          throw StateError(message);
        }
      } on FormatException {
        // Non-JSON responses fall through to the status-code error.
      }
      throw StateError('Resume request failed (${response.statusCode}).');
    }
  }
}
