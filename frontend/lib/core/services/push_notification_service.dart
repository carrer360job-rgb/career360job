import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

/// Sets up FCM at launch, but waits until a signed-in user reaches the portal
/// before asking for permission or fetching a device token.
class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();
  static const _permissionAskedKey = 'notification_permission_asked';

  Future<void>? _initialization;
  Future<void>? _portalRegistration;
  StreamSubscription<String>? _tokenRefreshSubscription;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _tokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh
          .listen((token) {
            unawaited(_registerRefreshedToken(token));
          });
    } catch (error) {
      _initialization = null;
      debugPrint('[Firebase Messaging Setup Notice] $error');
    }
  }

  Future<void> registerAfterPortalEntry() {
    return _portalRegistration ??= _registerAfterPortalEntry().whenComplete(() {
      _portalRegistration = null;
    });
  }

  Future<void> _registerRefreshedToken(String token) async {
    try {
      if (SupabaseService.client.auth.currentUser == null) return;
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
      await SupabaseService.registerDeviceFcmToken(token);
    } catch (error) {
      debugPrint('[Firebase Messaging Token Refresh Notice] $error');
    }
  }

  Future<void> _registerAfterPortalEntry() async {
    try {
      if (SupabaseService.client.auth.currentUser == null) return;
      await initialize();
      if (SupabaseService.client.auth.currentUser == null) return;

      final messaging = FirebaseMessaging.instance;
      var settings = await messaging.getNotificationSettings();
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!granted) {
        final preferences = SharedPreferencesAsync();
        if (await preferences.getBool(_permissionAskedKey) ?? false) return;
        if (SupabaseService.client.auth.currentUser == null) return;
        settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        await preferences.setBool(_permissionAskedKey, true);
      }

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }

      // getToken can show an OS permission prompt, so call it only after the
      // portal-entry permission check has succeeded.
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await SupabaseService.registerDeviceFcmToken(token);
      }
    } catch (error) {
      debugPrint('[Firebase Messaging Registration Notice] $error');
    }
  }
}
