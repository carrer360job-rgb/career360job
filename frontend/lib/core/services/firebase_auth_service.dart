import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

/// Full-Stack Authentication Service
/// Bridges Flutter client, Firebase Authentication, and Serverless Backend API
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Current logged in user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Retrieve current Firebase ID Token for authenticated API calls
  Future<String?> getIdToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } catch (e) {
      debugPrint('[FirebaseAuthService] Error fetching ID token: $e');
      return null;
    }
  }

  /// 1. Send 6-Digit Email OTP (via Serverless Backend API)
  Future<Map<String, dynamic>> sendEmailOtp({
    required String email,
    String? name,
    String type = 'verification',
  }) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}/api/auth/email-otp/send');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'name': name?.trim(),
          'type': type,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': data['message'] ?? 'Verification code sent to your email.',
          'resendWaitSeconds': data['resendWaitSeconds'] ?? 45,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to send verification email.',
        };
      }
    } catch (e) {
      debugPrint('[sendEmailOtp Network Error]: $e');
      return {
        'success': false,
        'message': 'Unable to connect to verification server. Please check internet connection.',
      };
    }
  }

  /// 2. Verify 6-Digit Email OTP & Authenticate Session
  Future<Map<String, dynamic>> verifyEmailOtp({
    required String email,
    required String otp,
    String? name,
    String? password,
  }) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}/api/auth/email-otp/verify');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'otp': otp.trim(),
          'name': name?.trim(),
          'password': password,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final customToken = data['customToken'] as String?;

        if (customToken != null && customToken.isNotEmpty) {
          try {
            await _auth.signInWithCustomToken(customToken);
          } catch (customTokenErr) {
            debugPrint('[Firebase Custom Token Notice]: $customTokenErr');
            // If custom token isn't accepted locally, fallback to email & password
            if (password != null && password.isNotEmpty) {
              await _fallbackEmailAuth(email: email, password: password, name: name);
            }
          }
        } else if (password != null && password.isNotEmpty) {
          await _fallbackEmailAuth(email: email, password: password, name: name);
        }

        return {
          'success': true,
          'message': data['message'] ?? 'Email verified successfully!',
          'user': data['user'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Invalid or expired verification code.',
        };
      }
    } catch (e) {
      debugPrint('[verifyEmailOtp Network Error]: $e');
      return {
        'success': false,
        'message': 'Verification service temporarily unavailable. Please retry.',
      };
    }
  }

  /// Helper: Local fallback email authentication when offline or testing
  Future<void> _fallbackEmailAuth({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (name != null && name.isNotEmpty) {
        await cred.user?.updateDisplayName(name.trim());
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      }
    }
  }

  /// 3. Email & Password Sign In + Backend Sync
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Sync profile to database asynchronously
    _syncUserProfileInBackground();

    return cred;
  }

  /// 4. Email & Password Direct Sign Up + Backend Sync
  Future<UserCredential> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (name.isNotEmpty) {
      await cred.user?.updateDisplayName(name.trim());
    }

    // Sync profile to database asynchronously
    _syncUserProfileInBackground();

    return cred;
  }

  /// 5. Google 1-Tap Sign-In + Backend Sync
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // User cancelled

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);

    // Sync Google user with backend database
    if (googleAuth.idToken != null) {
      _syncGoogleProfile(googleAuth.idToken!);
    } else {
      _syncUserProfileInBackground();
    }

    return cred;
  }

  /// 6. Send Password Reset via Firebase Official Action Link
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// 7. Send Password Reset via Custom 6-Digit Email OTP
  Future<Map<String, dynamic>> sendPasswordResetOtp(String email) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}/api/auth/forgot-password/send-otp');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim()}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': response.statusCode >= 200 && response.statusCode < 300,
        'message': data['message'] ?? 'Password reset instructions sent.',
        'resendWaitSeconds': data['resendWaitSeconds'] ?? 45,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to reach reset server. Please try again.',
      };
    }
  }

  /// 8. Verify OTP & Reset Password in Firebase
  Future<Map<String, dynamic>> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}/api/auth/forgot-password/verify-reset');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'otp': otp.trim(),
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': response.statusCode >= 200 && response.statusCode < 300,
        'message': data['message'] ?? 'Password reset status unknown.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to complete password reset. Please try again.',
      };
    }
  }

  /// 9. Background profile synchronization with PostgreSQL via Backend
  void _syncUserProfileInBackground() async {
    try {
      final token = await getIdToken();
      if (token == null) return;

      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/auth/sync-profile');
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (e) {
      debugPrint('[FirebaseAuthService] Background sync notice: $e');
    }
  }

  /// 10. Background Google profile synchronization
  void _syncGoogleProfile(String idToken) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/auth/google-sync');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );
    } catch (e) {
      debugPrint('[FirebaseAuthService] Google sync notice: $e');
    }
  }

  /// 11. Sign Out
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}
