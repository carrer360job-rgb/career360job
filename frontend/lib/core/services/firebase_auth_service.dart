import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Full-Stack Authentication & Profile Service
/// Pure Firebase Authentication & Cloud Firestore Integration
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current logged in user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Retrieve current Firebase ID Token for authenticated requests
  Future<String?> getIdToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } catch (e) {
      debugPrint('[FirebaseAuthService] Error fetching ID token: $e');
      return null;
    }
  }

  /// 1. Email/password sign-in requires a verified email address.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
    String role = 'candidate',
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = cred.user;
    if (user != null) {
      await user.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null || !refreshedUser.emailVerified) {
        try {
          await refreshedUser?.sendEmailVerification();
        } finally {
          await _auth.signOut();
        }
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message: 'Verify your email address before signing in.',
        );
      }
      unawaited(
        syncUserProfileToFirestore(
          uid: refreshedUser.uid,
          email: refreshedUser.email ?? email,
          displayName: refreshedUser.displayName,
          role: role,
        ),
      );
    }

    return cred;
  }

  /// 2. Create an account and send Firebase's email verification link.
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
    await cred.user?.sendEmailVerification();
    await _auth.signOut();

    return cred;
  }

  /// Resend Firebase's verification email for an authenticated unverified user.
  Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'requires-recent-login',
        message: 'Sign in again to request another verification email.',
      );
    }
    await user.sendEmailVerification();
  }

  /// 3. Google sign-in uses one Firebase browser flow on Android.
  Future<UserCredential?> signInWithGoogle({String role = 'candidate'}) async {
    try {
      final googleProvider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      final cred = await _auth.signInWithProvider(googleProvider);

      final user = cred.user;
      if (user != null) {
        unawaited(
          syncUserProfileToFirestore(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName,
            photoUrl: user.photoURL,
            role: role,
          ),
        );
      }

      return cred;
    } on FirebaseAuthException catch (e) {
      if (const {
        'web-context-canceled',
        'web-context-cancelled',
        'user-cancelled',
        'canceled',
        'cancelled',
      }.contains(e.code.toLowerCase())) {
        return null;
      }
      rethrow;
    }
  }

  /// 4. Send Password Reset via Firebase Official Action Link
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// 5. Sync Candidate Profile Directly to Cloud Firestore
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
      }, SetOptions(merge: true));
      debugPrint('[FirebaseAuthService] Firestore profile synced for $uid');
    } catch (e) {
      debugPrint('[FirebaseAuthService] Firestore sync notice: $e');
    }
  }

  /// 6. Save Candidate Complete Onboarding Profile to Cloud Firestore
  Future<void> saveCandidateOnboardingProfile({
    required String uid,
    required String email,
    required Map<String, dynamic> onboardingData,
  }) async {
    final batch = _firestore.batch();
    final candidateRef = _firestore.collection('candidates').doc(uid);
    final userRef = _firestore.collection('users').doc(uid);

    batch.set(candidateRef, {
      'uid': uid,
      ...onboardingData,
      'city': FieldValue.delete(),
      'onboardingCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(userRef, {
      'uid': uid,
      'email': email.toLowerCase().trim(),
      'role': 'candidate',
      'displayName': onboardingData['fullName'],
      'phone': onboardingData['phone'],
      'location': onboardingData['district'],
      'onboardingCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    debugPrint(
      '[FirebaseAuthService] Candidate onboarding profile saved for $uid',
    );
  }

  /// 7. Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
