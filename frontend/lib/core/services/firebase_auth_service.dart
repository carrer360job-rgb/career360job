import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

/// Full-Stack Authentication Service
/// Bridges Flutter client, Firebase Authentication, Cloud Firestore, and Serverless Backend API
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '91724152546-vtc0vna61drcpn0as33hsbkh7pq118k9.apps.googleusercontent.com',
  );

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
          'verificationToken': data['verificationToken'],
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
    String? verificationToken,
    String? name,
    String? password,
  }) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}/api/auth/email-otp/verify');
    http.Response response;
    try {
      response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'otp': otp.trim(),
          'verificationToken': verificationToken,
          'name': name?.trim(),
          'password': password,
        }),
      );
    } catch (netErr) {
      debugPrint('[verifyEmailOtp Network Error]: $netErr');
      return {
        'success': false,
        'message': 'Unable to connect to verification server. Please check your internet connection.',
      };
    }

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (jsonErr) {
      debugPrint('[verifyEmailOtp json error]: $jsonErr');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final customToken = data['customToken'] as String?;

      // Attempt Firebase client session in isolated try-catch so secondary auth errors never block verified users
      try {
        if (customToken != null && customToken.isNotEmpty) {
          try {
            await _auth.signInWithCustomToken(customToken);
          } catch (customTokenErr) {
            debugPrint('[Firebase Custom Token Notice]: $customTokenErr');
            if (password != null && password.isNotEmpty) {
              await _fallbackEmailAuth(email: email, password: password, name: name);
            }
          }
        } else if (password != null && password.isNotEmpty) {
          await _fallbackEmailAuth(email: email, password: password, name: name);
        }

        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          syncUserProfileToFirestore(
            uid: currentUser.uid,
            email: email,
            displayName: name ?? currentUser.displayName,
          );
        }
      } catch (authErr) {
        debugPrint('[verifyEmailOtp Local Firebase Session Notice]: $authErr');
      }

      return {
        'success': true,
        'message': data['message'] ?? 'Email verified successfully!',
        'user': data['user'],
      };
    } else {
      final errMsg = data['message'] ??
          (data['error'] is Map ? data['error']['message'] : data['error']) ??
          'Invalid or expired verification code.';
      return {
        'success': false,
        'message': errMsg.toString(),
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
        try {
          await _auth.signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
        } catch (signInErr) {
          debugPrint('[Firebase Fallback Sign In Notice]: $signInErr');
        }
      } else {
        debugPrint('[Firebase Fallback Create Notice]: $e');
      }
    } catch (generalErr) {
      debugPrint('[Firebase Fallback General Notice]: $generalErr');
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

  /// 4. Email & Password Direct Sign Up + Direct Cloud Firestore Profile Creation
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

    // Direct synchronous Firestore document creation
    final uid = cred.user?.uid;
    if (uid != null) {
      await syncUserProfileToFirestore(
        uid: uid,
        email: email,
        displayName: name.isNotEmpty ? name.trim() : null,
      );
    }

    // Optional background backend sync if configured
    _syncUserProfileInBackground();

    return cred;
  }

  /// 5. High-Speed Google Sign-In (Fast 1-Tap Native + Zero-Delay Browser Fallback)
  Future<UserCredential?> signInWithGoogle() async {
    // 1. Ultra-fast Native 1-Tap Prompt (150ms native bottom sheet)
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final cred = await _auth.signInWithCredential(credential);

        // Non-blocking background database sync
        if (googleAuth.idToken != null) {
          _syncGoogleProfile(googleAuth.idToken!);
        } else {
          _syncUserProfileInBackground();
        }

        return cred;
      } else {
        // User deliberately cancelled/dismissed native prompt
        return null;
      }
    } catch (nativeErr) {
      debugPrint('[FirebaseAuthService] Native 1-Tap notice ($nativeErr), activating seamless browser flow...');
    }

    // 2. High-Performance In-App Browser OAuth (Zero forced re-prompt delay)
    try {
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      final UserCredential cred = await _auth.signInWithProvider(googleProvider);

      // Non-blocking background database sync
      cred.user?.getIdToken().then((token) {
        if (token != null) {
          _syncGoogleProfile(token);
        } else {
          _syncUserProfileInBackground();
        }
      }).catchError((_) {});

      return cred;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'web-context-cancelled' || e.code == 'canceled' || e.code == 'cancelled') {
        debugPrint('[FirebaseAuthService] User dismissed the Google sign-in sheet.');
        return null;
      }
      rethrow;
    }
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
    String? verificationToken,
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
          'verificationToken': verificationToken,
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

  /// 9. Sync Candidate Profile Directly to Cloud Firestore
  Future<void> syncUserProfileToFirestore({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
    String role = 'candidate',
  }) async {
    try {
      final docRef = _firestore.collection('users').doc(uid);
      await docRef.set({
        'uid': uid,
        'email': email.toLowerCase().trim(),
        'displayName': displayName ?? email.split('@')[0],
        'photoUrl': photoUrl,
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[FirebaseAuthService] Firestore profile synced for $uid');
    } catch (e) {
      debugPrint('[FirebaseAuthService] Firestore sync notice: $e');
    }
  }

  /// 9.1 Save Candidate Complete Onboarding Profile to Cloud Firestore
  Future<void> saveCandidateOnboardingProfile({
    required String uid,
    required Map<String, dynamic> onboardingData,
  }) async {
    try {
      final docRef = _firestore.collection('candidates').doc(uid);
      await docRef.set({
        'uid': uid,
        ...onboardingData,
        'onboardingCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final userRef = _firestore.collection('users').doc(uid);
      await userRef.set({
        'uid': uid,
        'displayName': onboardingData['fullName'],
        'phone': onboardingData['phone'],
        'location': onboardingData['city'] ?? onboardingData['district'],
        'onboardingCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[FirebaseAuthService] Candidate onboarding profile saved for $uid');
    } catch (e) {
      debugPrint('[FirebaseAuthService] Firestore candidate profile notice: $e');
    }
  }

  /// 10. Background profile synchronization via Backend
  void _syncUserProfileInBackground() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        syncUserProfileToFirestore(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          photoUrl: user.photoURL,
        );
      }

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

  /// 11. Background Google profile synchronization
  void _syncGoogleProfile(String idToken) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        syncUserProfileToFirestore(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          photoUrl: user.photoURL,
        );
      }

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

  /// 12. Sign Out
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}
