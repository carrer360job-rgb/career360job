import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Complete Supabase Authentication Service
/// Handles Email/Password, Phone OTP, Session persistence & Profile sync
class SupabaseAuthService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Current authenticated Supabase User
  User? get currentUser => _client.auth.currentUser;

  /// Current authenticated Supabase Session
  Session? get currentSession => _client.auth.currentSession;

  /// Current User ID
  String? get currentUid => _client.auth.currentUser?.id;

  /// Stream of Supabase Auth State changes
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Stream of User changes (maps AuthState to User?)
  Stream<User?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session?.user);

  /// Sign In with Email & Password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      debugPrint('[SupabaseAuthService] Sign-in error: ${e.message}');
      rethrow;
    }
  }

  /// Sign Up with Email & Password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
    String role = 'CANDIDATE',
  }) async {
    try {
      final settingsResponse = await http.get(
        Uri.parse('${SupabaseService.supabaseUrl}/auth/v1/settings'),
        headers: {'apikey': SupabaseService.supabaseAnonKey},
      );
      if (settingsResponse.statusCode != 200) {
        throw StateError('Email verification is unavailable. Try again later.');
      }
      final settings =
          jsonDecode(settingsResponse.body) as Map<String, dynamic>;
      if (settings['mailer_autoconfirm'] != false) {
        throw StateError(
          'Email OTP verification is not enabled. Please contact support.',
        );
      }

      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          if (fullName != null) 'full_name': fullName.trim(),
          'role': role,
        },
      );
      if (response.session != null) {
        await _client.auth.signOut();
        throw StateError('Email verification must be enabled before signup.');
      }
      return response;
    } on AuthException catch (e) {
      debugPrint('[SupabaseAuthService] Sign-up error: ${e.message}');
      rethrow;
    }
  }

  Future<AuthResponse> verifySignupOtp({
    required String email,
    required String token,
    required String role,
  }) async {
    final response = await _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
    final user = response.user;
    if (response.session == null ||
        user == null ||
        user.emailConfirmedAt == null) {
      throw StateError('The email code could not be verified. Try again.');
    }
    await _client.from('profiles').upsert({
      'id': user.id,
      'email': user.email,
      'role': role,
      'updated_at': DateTime.now().toIso8601String(),
    });
    return response;
  }

  Future<void> resendSignupOtp(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email.trim());
  }

  /// Sign In / Request OTP with Phone Number (+91 format for India)
  Future<void> signInWithPhoneOtp({required String phone}) async {
    final formattedPhone = phone.startsWith('+') ? phone : '+91$phone';
    await _client.auth.signInWithOtp(phone: formattedPhone);
  }

  /// Verify Phone OTP
  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    final formattedPhone = phone.startsWith('+') ? phone : '+91$phone';
    return await _client.auth.verifyOTP(
      phone: formattedPhone,
      token: token.trim(),
      type: OtpType.sms,
    );
  }

  /// Sign In with Google OAuth (Browser redirect flow)
  Future<bool> signInWithGoogle({String? redirectTo}) async {
    try {
      final redirect =
          redirectTo ??
          (kIsWeb ? null : 'io.supabase.career360://login-callback/');
      return await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirect,
      );
    } on AuthException catch (e) {
      debugPrint('[SupabaseAuthService] Google OAuth error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[SupabaseAuthService] Google sign-in failure: $e');
      rethrow;
    }
  }

  /// Send Password Reset Email
  Future<void> resetPassword({required String email}) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  /// Sign Out current user
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('[SupabaseAuthService] Sign-out error: $e');
    }
  }
}
