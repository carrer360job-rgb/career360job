import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Current logged in user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 1. Send 6-Digit Email OTP (via Backend API)
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
      return {
        'success': false,
        'message': 'Unable to connect to server. Please try again.',
      };
    }
  }

  /// 2. Verify 6-Digit Email OTP & Sign In (via Backend API + Firebase)
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
        // If backend returned a Firebase Custom Token, sign in to Firebase
        final customToken = data['customToken'] as String?;
        if (customToken != null && customToken.isNotEmpty) {
          await _auth.signInWithCustomToken(customToken);
        } else if (password != null && password.isNotEmpty) {
          // Fallback: create or sign in with Firebase Auth directly
          try {
            await _auth.createUserWithEmailAndPassword(
              email: email.trim(),
              password: password,
            );
            if (name != null) {
              await _auth.currentUser?.updateDisplayName(name.trim());
            }
          } catch (_) {
            await _auth.signInWithEmailAndPassword(
              email: email.trim(),
              password: password,
            );
          }
        }

        return {
          'success': true,
          'message': data['message'] ?? 'Email verified successfully!',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Invalid verification code.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Verification failed. Please check connection.',
      };
    }
  }

  /// 3. Email & Password Sign In
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// 4. Email & Password Sign Up
  Future<UserCredential> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user?.updateDisplayName(name.trim());
    return cred;
  }

  /// 5. Google 1-Tap Sign-In
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  /// 6. Send Password Reset Email
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// 7. Sign Out
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}
