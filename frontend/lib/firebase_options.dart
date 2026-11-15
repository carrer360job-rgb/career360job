// File generated for Career360 Firebase Push Notifications
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA0JRZw6aP67yMJZTpjSjY6jdiJQN0njig',
    appId: '1:81350877440:web:9869bc98c8f2bc10f313e5',
    messagingSenderId: '81350877440',
    projectId: 'carrer360-fa344',
    storageBucket: 'carrer360-fa344.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA0JRZw6aP67yMJZTpjSjY6jdiJQN0njig',
    appId: '1:81350877440:android:9869bc98c8f2bc10f313e5',
    messagingSenderId: '81350877440',
    projectId: 'carrer360-fa344',
    storageBucket: 'carrer360-fa344.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA0JRZw6aP67yMJZTpjSjY6jdiJQN0njig',
    appId: '1:81350877440:ios:9869bc98c8f2bc10f313e5',
    messagingSenderId: '81350877440',
    projectId: 'carrer360-fa344',
    storageBucket: 'carrer360-fa344.firebasestorage.app',
  );
}
