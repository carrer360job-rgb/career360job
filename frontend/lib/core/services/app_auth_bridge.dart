import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'supabase_service.dart';

/// Unified Application User Model bridging Supabase and Firebase
class AppAuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  final bool emailVerified;

  const AppAuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.emailVerified = true,
  });

  Future<void> sendEmailVerification() async {}
  Future<void> reload() async {}
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    return SupabaseService.client.auth.currentSession?.accessToken;
  }
}

class AppAuthBridge {
  static AppAuthUser? _mapSupabaseUser(sb.User? user) {
    if (user == null) return null;
    return AppAuthUser(
      uid: user.id,
      email: user.email,
      displayName: user.userMetadata?['full_name'] as String? ??
          user.userMetadata?['name'] as String? ??
          user.email?.split('@').first,
      emailVerified: true, // We disabled email confirmation in Supabase
    );
  }

  static AppAuthUser? _mapFirebaseUser(fb.User? user) {
    if (user == null) return null;
    return AppAuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName ?? user.email?.split('@').first,
      emailVerified: user.emailVerified,
    );
  }

  /// Current Active User (Supabase primary, Firebase fallback)
  static AppAuthUser? get currentUser {
    final sbUser = SupabaseService.client.auth.currentUser;
    if (sbUser != null) return _mapSupabaseUser(sbUser);

    try {
      final fbUser = fb.FirebaseAuth.instance.currentUser;
      if (fbUser != null) return _mapFirebaseUser(fbUser);
    } catch (_) {}

    return null;
  }

  /// Unified Auth State Changes Stream
  static Stream<AppAuthUser?> get authStateChanges {
    final controller = StreamController<AppAuthUser?>.broadcast();

    // 1. Listen to Supabase Auth State
    final sbSub = SupabaseService.client.auth.onAuthStateChange.listen((data) {
      controller.add(_mapSupabaseUser(data.session?.user));
    }, onError: (_) {});

    // 2. Also listen to Firebase Auth State as fallback
    StreamSubscription? fbSub;
    try {
      fbSub = fb.FirebaseAuth.instance.userChanges().listen((fbUser) {
        if (SupabaseService.client.auth.currentUser == null) {
          controller.add(_mapFirebaseUser(fbUser));
        }
      }, onError: (_) {});
    } catch (_) {}

    controller.onCancel = () {
      sbSub.cancel();
      fbSub?.cancel();
    };

    // Emit initial state
    controller.add(currentUser);

    return controller.stream;
  }

  /// Global Sign Out
  static Future<void> signOut() async {
    try {
      await SupabaseService.client.auth.signOut();
    } catch (_) {}
    try {
      await fb.FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}
