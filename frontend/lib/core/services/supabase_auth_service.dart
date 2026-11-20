import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

enum PasswordRecoveryRole { candidate, employer }

/// Complete Supabase Authentication Service
/// Handles Email/Password, Phone OTP, Session persistence & Profile sync
class SupabaseAuthService {
  static SupabaseClient get _client => SupabaseService.client;
  static const _recoveryPreference = 'password_recovery_verified';
  static const _recoveryRolePreference = 'password_recovery_role';
  static const _suspensionNoticePreference = 'account_suspended_notice';
  static const _pendingOAuthRolePreference = 'pending_oauth_role';
  static final ValueNotifier<bool> recoveryVerified = ValueNotifier(false);
  static final ValueNotifier<bool> suspensionNotice = ValueNotifier(false);
  static bool recoveryInProgress = false;
  static PasswordRecoveryRole? recoveryRole;

  static Future<void> restoreRecoveryState() async {
    final preferences = SharedPreferencesAsync();
    final pending = await preferences.getBool(_recoveryPreference) ?? false;
    recoveryVerified.value = pending && _client.auth.currentSession != null;
    recoveryInProgress = recoveryVerified.value;
    final storedRole = await preferences.getString(_recoveryRolePreference);
    recoveryRole = recoveryVerified.value
        ? PasswordRecoveryRole.values
              .where((role) => role.name == storedRole)
              .firstOrNull
        : null;
    if (pending && !recoveryVerified.value) {
      await preferences.remove(_recoveryPreference);
      await preferences.remove(_recoveryRolePreference);
    }
  }

  static Future<void> clearRecoveryState() async {
    recoveryVerified.value = false;
    recoveryInProgress = false;
    recoveryRole = null;
    final preferences = SharedPreferencesAsync();
    await preferences.remove(_recoveryPreference);
    await preferences.remove(_recoveryRolePreference);
  }

  static Future<void> restoreSuspensionNotice() async {
    suspensionNotice.value =
        await SharedPreferencesAsync().getBool(_suspensionNoticePreference) ??
        false;
  }

  static Future<void> showSuspensionNotice() async {
    if (suspensionNotice.value) return;
    suspensionNotice.value = true;
    await SharedPreferencesAsync().setBool(_suspensionNoticePreference, true);
  }

  static Future<void> clearSuspensionNotice() async {
    suspensionNotice.value = false;
    await SharedPreferencesAsync().remove(_suspensionNoticePreference);
  }

  static bool isSuspendedSignInError(Object error) =>
      error is AuthException && error.code == 'user_banned';

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
      await SharedPreferencesAsync().remove(_pendingOAuthRolePreference);
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      await clearSuspensionNotice();
      return response;
    } on AuthException catch (e) {
      if (isSuspendedSignInError(e)) await showSuspensionNotice();
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
    Map<String, dynamic> profileMetadata = const {},
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
          ...profileMetadata,
        },
      );
      if (response.session != null) {
        await _client.auth.signOut();
        throw StateError('Email verification must be enabled before signup.');
      }
      if (response.user == null) {
        throw StateError('Could not start email verification. Try again.');
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
    await ensureAccountProfile(preferredRole: role);
    return response;
  }

  /// Creates a missing account row once a verified user has signed in.
  /// Existing rows, including suspended accounts, are never modified.
  Future<Map<String, dynamic>> ensureAccountProfile({
    String? preferredRole,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || user.emailConfirmedAt == null) {
      throw StateError('Verify your email before entering the portal.');
    }

    Future<Map<String, dynamic>?> readProfile() => _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    final existing = await readProfile();
    if (existing != null) {
      await SharedPreferencesAsync().remove(_pendingOAuthRolePreference);
      return existing;
    }

    final pendingRole = await SharedPreferencesAsync().getString(
      _pendingOAuthRolePreference,
    );
    final metadataRole = user.userMetadata?['role']?.toString().toUpperCase();
    const allowedRoles = {'CANDIDATE', 'EMPLOYER'};
    final role = [metadataRole, pendingRole, preferredRole?.toUpperCase()]
        .whereType<String>()
        .firstWhere(allowedRoles.contains, orElse: () => 'CANDIDATE');

    try {
      await _client.from('profiles').insert({
        'id': user.id,
        'email': user.email?.trim().toLowerCase(),
        'role': role,
      });
    } on PostgrestException catch (error) {
      // Another auth callback may have created the row at the same time.
      if (error.code != '23505') rethrow;
    }
    final profile = await readProfile();
    if (profile == null) {
      throw StateError('Could not load your account. Please try again.');
    }
    await SharedPreferencesAsync().remove(_pendingOAuthRolePreference);
    return profile;
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
  Future<bool> signInWithGoogle({
    String? redirectTo,
    String role = 'CANDIDATE',
  }) async {
    try {
      if (!{'CANDIDATE', 'EMPLOYER'}.contains(role)) {
        throw ArgumentError.value(role, 'role', 'Unsupported account role');
      }
      await SharedPreferencesAsync().setString(_pendingOAuthRolePreference, role);
      final redirect =
          redirectTo ??
          (kIsWeb ? null : 'io.supabase.career360://login-callback/');
      final success = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirect,
      );
      if (!success) {
        await SharedPreferencesAsync().remove(_pendingOAuthRolePreference);
      }
      return success;
    } on AuthException catch (e) {
      await SharedPreferencesAsync().remove(_pendingOAuthRolePreference);
      debugPrint('[SupabaseAuthService] Google OAuth error: ${e.message}');
      rethrow;
    } catch (e) {
      await SharedPreferencesAsync().remove(_pendingOAuthRolePreference);
      debugPrint('[SupabaseAuthService] Google sign-in failure: $e');
      rethrow;
    }
  }

  /// Send Password Reset Email / OTP
  Future<void> resetPassword({required String email}) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  /// Resend Password Reset OTP
  Future<void> resendPasswordResetOtp({required String email}) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  /// A verified recovery code creates a temporary authenticated session.
  Future<void> verifyPasswordResetOtp({
    required String email,
    required String token,
    required PasswordRecoveryRole role,
  }) async {
    recoveryInProgress = true;
    try {
      final preferences = SharedPreferencesAsync();
      await preferences.setString(_recoveryRolePreference, role.name);
      await preferences.setBool(_recoveryPreference, true);
      final response = await _client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.recovery,
      );
      if (response.session == null) {
        throw StateError(
          'The recovery code could not be verified. Please try again.',
        );
      }
      recoveryRole = role;
      recoveryVerified.value = true;
    } catch (_) {
      recoveryInProgress = false;
      final preferences = SharedPreferencesAsync();
      await preferences.remove(_recoveryPreference);
      await preferences.remove(_recoveryRolePreference);
      rethrow;
    }
  }

  Future<void> updatePasswordAfterRecovery(String newPassword) async {
    if (!recoveryVerified.value || _client.auth.currentSession == null) {
      throw StateError(
        'Your recovery session has expired. Request a new code.',
      );
    }
    await _client.auth.updateUser(UserAttributes(password: newPassword));
    await _client.auth.signOut();
    await clearRecoveryState();
  }

  Future<void> cancelPasswordRecovery() async {
    await _client.auth.signOut();
    await clearRecoveryState();
  }

  /// Sign Out current user
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      await SharedPreferencesAsync().remove(_pendingOAuthRolePreference);
    } catch (e) {
      debugPrint('[SupabaseAuthService] Sign-out error: $e');
    }
  }
}
