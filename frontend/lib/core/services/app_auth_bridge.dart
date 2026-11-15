import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

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

  Future<void> sendEmailVerification() async {
    if (email == null) throw StateError('Account email is unavailable.');
    await SupabaseService.client.auth.resend(
      type: sb.OtpType.signup,
      email: email!,
    );
  }

  Future<void> reload() async {
    await SupabaseService.client.auth.getUser();
  }

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
      displayName:
          user.userMetadata?['full_name'] as String? ??
          user.userMetadata?['name'] as String? ??
          user.email?.split('@').first,
      emailVerified: user.emailConfirmedAt != null,
    );
  }

  /// Current Supabase Auth user.
  static AppAuthUser? get currentUser {
    final sbUser = SupabaseService.client.auth.currentUser;
    return _mapSupabaseUser(sbUser);
  }

  /// Unified Auth State Changes Stream
  static Stream<AppAuthUser?> get authStateChanges {
    late final StreamController<AppAuthUser?> controller;
    StreamSubscription? sbSub;
    controller = StreamController<AppAuthUser?>.broadcast(
      onListen: () {
        sbSub = SupabaseService.client.auth.onAuthStateChange.listen((data) {
          controller.add(_mapSupabaseUser(data.session?.user));
        }, onError: (_) {});

        // Emit the restored session only after the UI has subscribed.
        controller.add(currentUser);
      },
      onCancel: () {
        sbSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Global Sign Out
  static Future<void> signOut() async {
    try {
      await SupabaseService.client.auth.signOut();
    } catch (_) {}
  }
}
